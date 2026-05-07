/**
 * Normalize raw Facebook Messenger webhook events into a stable internal shape.
 *
 * The controller keeps direct Meta transport ownership, but downstream services
 * should receive normalized sender/message payloads so the conversation flow can
 * evolve without depending on raw webhook quirks.
 */
function normalizeMessengerWebhookEvent(messagingEvent) {
  const senderId = messagingEvent?.sender?.id || null;
  if (!senderId) {
    return null;
  }

  const message = messagingEvent?.message && typeof messagingEvent.message === 'object'
    ? messagingEvent.message
    : null;

  const attachments = Array.isArray(message?.attachments) ? message.attachments : [];
  const text = typeof message?.text === 'string' ? message.text.trim() : '';
  const quickReplyPayload = typeof message?.quick_reply?.payload === 'string'
    ? (message.quick_reply.payload.trim() || null)
    : null;
  const postbackPayload = messagingEvent?.postback
    ? (typeof messagingEvent.postback.payload === 'string' ? (messagingEvent.postback.payload.trim() || null) : null)
    : null;
  const optinRef = messagingEvent?.optin
    ? (typeof messagingEvent.optin.ref === 'string' ? (messagingEvent.optin.ref.trim() || '') : '')
    : null;

  return {
    senderId,
    message: message
      ? {
        isEcho: Boolean(message.is_echo),
        text,
        attachments,
        quickReplyPayload,
      }
      : null,
    postbackPayload,
    optinRef,
    raw: messagingEvent,
  };
}

module.exports = {
  normalizeMessengerWebhookEvent,
};
