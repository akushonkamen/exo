use crate::{AgentConfig, ConversationConfig};
use anyhow::{Result, bail};
use std::path::Path;

pub(crate) fn validate_thread(
    mcp: &crate::managed_mcp::PreparedMcp,
    store: &exoharness::BasicExoHarnessConfig,
    agent_config: &AgentConfig,
    config: &ConversationConfig,
) -> Result<()> {
    let provider = config
        .sandbox_provider
        .as_ref()
        .unwrap_or(&agent_config.sandbox.provider);
    if *provider != exoharness::SandboxProvider::LocalProcess {
        for mount in agent_config
            .sandbox
            .mounts
            .iter()
            .chain(config.mounts.iter())
        {
            store.validate_secret_mount(Path::new(&mount.host_path))?;
        }
    } else if let Some(selection) = &mcp.selection
        && (selection.vaults.len() > 1 || selection.bindings.iter().any(|b| b.secret.is_some()))
    {
        bail!(
            "vault-backed chat requires an isolated sandbox; local-process can read host credentials"
        );
    }
    Ok(())
}
