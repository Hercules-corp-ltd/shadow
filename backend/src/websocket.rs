// Hermes - Messenger God
// Handles real-time WebSocket communication for Solana events and updates

use actix_web::{web, HttpRequest, HttpResponse};
use actix_ws::Message;
use futures_util::StreamExt;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::broadcast;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum HermesMessage {
    Subscribe {
        wallet: Option<String>,
        program: Option<String>,
    },
    Unsubscribe {
        wallet: Option<String>,
        program: Option<String>,
    },
    Ping,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum HermesResponse {
    Subscribed { topic: String },
    Unsubscribed { topic: String },
    Event { topic: String, data: serde_json::Value },
    Pong,
    Error { message: String },
}

pub struct HermesBroker {
    // Broadcast channels for different topics
    // In production, this would be backed by Redis or similar
    channels: Arc<tokio::sync::Mutex<HashMap<String, broadcast::Sender<String>>>>,
}

impl HermesBroker {
    pub fn new() -> Self {
        Self {
            channels: Arc::new(tokio::sync::Mutex::new(HashMap::new())),
        }
    }

    pub async fn subscribe(&self, topic: String) -> broadcast::Receiver<String> {
        let mut channels = self.channels.lock().await;
        let sender = channels.entry(topic.clone())
            .or_insert_with(|| {
                let (tx, _) = broadcast::channel(100);
                tx
            })
            .clone();
        
        sender.subscribe()
    }

    pub async fn publish(&self, topic: &str, message: String) {
        let channels = self.channels.lock().await;
        if let Some(sender) = channels.get(topic) {
            let _ = sender.send(message);
        }
    }
}

impl Default for HermesBroker {
    fn default() -> Self {
        Self::new()
    }
}

pub async fn ws_handler(
    req: HttpRequest,
    body: web::Payload,
) -> Result<HttpResponse, actix_web::Error> {
    let (response, mut session, mut msg_stream) = actix_ws::handle(&req, body)?;

    actix_web::rt::spawn(async move {
        let mut subscriptions: Vec<String> = Vec::new();
        
        while let Some(Ok(msg)) = msg_stream.next().await {
            match msg {
                Message::Text(text) => {
                    // Parse message
                    if let Ok(hermes_msg) = serde_json::from_str::<HermesMessage>(&text) {
                        match hermes_msg {
                            HermesMessage::Subscribe { wallet, program } => {
                                if let Some(w) = wallet {
                                    let topic = format!("wallet:{}", w);
                                    subscriptions.push(topic.clone());
                                    let response = HermesResponse::Subscribed { topic };
                                    if let Ok(json) = serde_json::to_string(&response) {
                                        let _ = session.text(json).await;
                                    }
                                }
                                if let Some(p) = program {
                                    let topic = format!("program:{}", p);
                                    subscriptions.push(topic.clone());
                                    let response = HermesResponse::Subscribed { topic };
                                    if let Ok(json) = serde_json::to_string(&response) {
                                        let _ = session.text(json).await;
                                    }
                                }
                            }
                            HermesMessage::Unsubscribe { wallet, program } => {
                                if let Some(w) = wallet {
                                    let topic = format!("wallet:{}", w);
                                    subscriptions.retain(|t| t != &topic);
                                    let response = HermesResponse::Unsubscribed { topic };
                                    if let Ok(json) = serde_json::to_string(&response) {
                                        let _ = session.text(json).await;
                                    }
                                }
                                if let Some(p) = program {
                                    let topic = format!("program:{}", p);
                                    subscriptions.retain(|t| t != &topic);
                                    let response = HermesResponse::Unsubscribed { topic };
                                    if let Ok(json) = serde_json::to_string(&response) {
                                        let _ = session.text(json).await;
                                    }
                                }
                            }
                            HermesMessage::Ping => {
                                let response = HermesResponse::Pong;
                                if let Ok(json) = serde_json::to_string(&response) {
                                    let _ = session.text(json).await;
                                }
                            }
                        }
                    } else {
                        // Echo for debugging (remove in production)
                        let response = HermesResponse::Error {
                            message: "Invalid message format".to_string(),
                        };
                        if let Ok(json) = serde_json::to_string(&response) {
                            let _ = session.text(json).await;
                        }
                    }
                }
                Message::Close(_) => break,
                _ => {}
            }
        }
    });

    Ok(response)
}

