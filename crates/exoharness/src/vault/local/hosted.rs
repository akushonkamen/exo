use super::*;
use futures::channel::oneshot;
use std::{collections::HashMap, sync::Mutex};

pub(super) struct RefreshState {
    host: Arc<dyn crate::runtime_host::RuntimeHost>,
    http: Option<Arc<dyn OAuthHttpClient>>,
    locks: Mutex<HashMap<SecretId, std::sync::Weak<tokio::sync::Mutex<()>>>>,
}
impl RefreshState {
    pub(super) fn new(
        host: Arc<dyn crate::runtime_host::RuntimeHost>,
        http: Option<Arc<dyn OAuthHttpClient>>,
    ) -> Self {
        Self {
            host,
            http,
            locks: Mutex::default(),
        }
    }
    fn lock(&self, id: SecretId) -> Arc<tokio::sync::Mutex<()>> {
        let mut locks = self.locks.lock().expect("OAuth refresh locks poisoned");
        locks.retain(|_, lock| lock.strong_count() > 0);
        if let Some(lock) = locks.get(&id).and_then(std::sync::Weak::upgrade) {
            return lock;
        }
        let lock = Arc::new(tokio::sync::Mutex::new(()));
        locks.insert(id, Arc::downgrade(&lock));
        lock
    }
}
impl BasicVaultHandle {
    pub(super) async fn resolve_credentials(
        &self,
        id: &SecretId,
        target: &CredentialDestination,
    ) -> Result<ResolvedSecret> {
        let resolved = self.read_for_destination(id, target).await?;
        anyhow::ensure!(
            !matches!(resolved.secret, Secret::GithubCli { .. }),
            "GitHub CLI credentials require a native host; use a token or OAuth grant"
        );
        if oauth::needs_refresh(&resolved.secret) {
            return self
                .refresh_task(id, target, resolved.revision, false)
                .await;
        }
        Ok(resolved)
    }
    pub(super) async fn refresh_task(
        &self,
        id: &SecretId,
        target: &CredentialDestination,
        revision: u64,
        force: bool,
    ) -> Result<ResolvedSecret> {
        let vault = self.clone();
        let id = *id;
        let target = target.clone();
        let (done, completion) = oneshot::channel();
        // Persist rotated refresh tokens even when the MCP request is cancelled.
        self.store.inner.hosted.host.spawn(Box::pin(async move {
            let result = async {
                let lock = vault.store.inner.hosted.lock(id);
                let _guard = lock.lock().await;
                let resolved = vault.read_for_destination(&id, &target).await?;
                if resolved.revision != revision
                    || (!force && !oauth::needs_refresh(&resolved.secret))
                {
                    return Ok(resolved);
                }
                let http = vault
                    .store
                    .inner
                    .hosted
                    .http
                    .as_ref()
                    .context("this host does not support credential refresh")?;
                let secret = oauth::refresh(resolved.secret.clone(), http.as_ref()).await?;
                vault
                    .persist_refreshed(&id, &target, resolved, secret)
                    .await
            }
            .await;
            if done.send(result).is_err() {
                tracing::debug!("OAuth caller stopped before refresh finished");
            }
        }));
        completion
            .await
            .context("host stopped before credential refresh finished")?
    }
}
