use crate::remote::IdentityGrant;
use anyhow::{Context, Result};
use exoharness::{AgentId, EventId, Storage, ThreadId, TurnRecord, Uuid7};
use serde::{Deserialize, Serialize, de::DeserializeOwned};
use sha2::{Digest, Sha256};
use std::sync::Arc;

pub fn digest(value: &str) -> String {
    format!("{:x}", Sha256::digest(value.as_bytes()))
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct IncomingMessage {
    pub id: String,
    pub account: String,
    pub conversation: String,
    pub sender: String,
    pub text: String,
    pub channel: String,
    pub message_ts: String,
    pub reply_ts: Option<String>,
    pub direct: bool,
    pub external: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Inbox {
    pub accepted: Uuid7,
    pub message: IncomingMessage,
    pub grant: Option<IdentityGrant>,
    pub thread: Option<ThreadId>,
    pub turn: Option<TurnRecord>,
    pub cursor: Option<EventId>,
    pub final_text: Option<String>,
    #[serde(default)]
    pub progress: super::progress::Progress,
    pub complete: bool,
    pub error: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SenderContext {
    pub account: String,
    pub sender: String,
    pub channel: String,
    pub direct: bool,
    pub external: bool,
}
impl From<&IncomingMessage> for SenderContext {
    fn from(message: &IncomingMessage) -> Self {
        Self {
            account: message.account.clone(),
            sender: message.sender.clone(),
            channel: message.channel.clone(),
            direct: message.direct,
            external: message.external,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Authority {
    pub deployment: String,
    pub agent: AgentId,
    pub thread: ThreadId,
    pub adapter: String,
    pub source: SenderContext,
    pub grant: Option<IdentityGrant>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Route {
    pub thread: Option<ThreadId>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DeliveryKind {
    Stream {
        chunks: Vec<slack_morphism::prelude::SlackStreamChunk>,
        complete: bool,
        sender: String,
        thread_ts: String,
    },
    Status {
        inbox: String,
        thread_ts: String,
        text: String,
    },
    Text {
        text: String,
    },
    Reaction {
        message_ts: String,
    },
    Approval {
        turn: TurnRecord,
        approval: crate::permissions::ApprovalRequest,
        inbox: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Outbox {
    pub id: String,
    pub account: String,
    pub channel: String,
    pub reply_ts: Option<String>,
    pub kind: DeliveryKind,
    pub sent: bool,
    pub attempts: u32,
    pub retry_at: i64,
    pub external_id: Option<String>,
}

#[derive(Clone)]
pub struct AdapterStore {
    storage: Arc<dyn Storage>,
}

impl AdapterStore {
    pub fn new(storage: Arc<dyn Storage>) -> Self {
        Self { storage }
    }
    pub async fn get<T: DeserializeOwned>(&self, key: &str) -> Result<Option<T>> {
        self.storage
            .get(key)
            .await?
            .map(|bytes| {
                serde_json::from_slice(&bytes)
                    .with_context(|| format!("reading adapter record {key}"))
            })
            .transpose()
    }
    pub async fn put<T: Serialize>(&self, key: &str, value: &T) -> Result<()> {
        self.storage
            .put(key, serde_json::to_vec(value)?, false)
            .await
    }
    pub async fn list<T: DeserializeOwned>(&self, prefix: &str) -> Result<Vec<T>> {
        let mut records = Vec::new();
        for key in self.storage.list(prefix).await? {
            if key.ends_with(".json")
                && let Some(record) = self.get(&key).await?
            {
                records.push(record);
            }
        }
        Ok(records)
    }
    pub fn deployment(agent: AgentId, name: &str) -> String {
        digest(&format!("{agent}/{name}"))
    }
    pub fn inbox(deployment: &str, id: &str) -> String {
        format!("adapters/v1/{deployment}/inbox/{}.json", digest(id))
    }
    pub fn route(deployment: &str, message: &IncomingMessage) -> String {
        format!(
            "adapters/v1/{deployment}/routes/{}.json",
            digest(&format!("{}/{}", message.account, message.conversation))
        )
    }
    pub fn outbox(deployment: &str, id: &str) -> String {
        format!("adapters/v1/{deployment}/outbox/{}.json", digest(id))
    }
    pub fn authority(principal: &str) -> String {
        format!("adapters/v1/authorities/{}.json", digest(principal))
    }
}
