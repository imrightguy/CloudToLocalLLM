// ─── Classification Service — Voice AI ───
// Classifie les transcripts d'appels de maintenance via LLM.
// Fallback: classification basique si LLM indisponible.

const logger = require('../utils/logger');

const VALID_URGENCIES = ['basse', 'moyenne', 'haute', 'urgence'];
const VALID_CATEGORIES = ['plomberie', 'électrique', 'chauffage', 'structure', 'autre'];

/**
 * Classifie une demande de maintenance à partir d'un transcript d'appel.
 * @param {string} transcript - Texte complet de l'appel (français)
 * @returns {Promise<{urgency: string, category: string, summary: string}>}
 */
async function classifyMaintenanceRequest(transcript) {
  const text = (transcript || '').trim();
  if (!text || text.length < 10) {
    return { urgency: 'moyenne', category: 'autre', summary: text.slice(0, 200) || 'Demande de maintenance' };
  }

  // Essayer le LLM d'abord
  try {
    const llmResult = await _classifyWithLLM(text);
    if (llmResult) return llmResult;
  } catch (error) {
    logger.warn('[classification.service] LLM indisponible, fallback règles:', error.message);
  }

  // Fallback: classification par règles
  return _classifyByRules(text);
}

/**
 * Appelle un LLM (OpenAI/Claude) pour classifier le transcript.
 */
async function _classifyWithLLM(transcript) {
  const apiKey = process.env.OPENAI_API_KEY || process.env.CLAUDE_API_KEY;
  if (!apiKey) {
    logger.warn('[classification.service] Aucune clé LLM configurée');
    return null;
  }

  const isClaude = Boolean(process.env.CLAUDE_API_KEY);
  const model = isClaude ? 'claude-3-haiku-20240307' : (process.env.OPENAI_MODEL || 'gpt-4o-mini');
  const baseUrl = isClaude
    ? 'https://api.anthropic.com/v1/messages'
    : 'https://api.openai.com/v1/chat/completions';

  const prompt = `Tu es un classifieur de maintenance immobilière au Québec. Analyse ce transcript d'appel d'un locataire et retourne UNIQUEMENT un objet JSON valide avec ces 3 champs:
- "urgency": "basse"|"moyenne"|"haute"|"urgence" (urgence = danger immédiat: incendie, inondation, gaz)
- "category": "plomberie"|"électrique"|"chauffage"|"structure"|"autre"
- "summary": résumé en 1 phrase française (max 200 caractères)

Transcript:
"""
${transcript.slice(0, 4000)}
"""

JSON:`;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);

  try {
    let body;
    if (isClaude) {
      body = JSON.stringify({
        model,
        max_tokens: 200,
        messages: [{ role: 'user', content: prompt }],
      });
    } else {
      body = JSON.stringify({
        model,
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 200,
        temperature: 0,
        response_format: { type: 'json_object' },
      });
    }

    const headers = {
      'Content-Type': 'application/json',
      Authorization: isClaude
        ? `x-api-key ${apiKey}`
        : `Bearer ${apiKey}`,
    };
    if (isClaude) headers['anthropic-version'] = '2023-06-01';

    const response = await fetch(baseUrl, {
      method: 'POST',
      headers,
      body,
      signal: controller.signal,
    });

    if (!response.ok) {
      logger.warn(`[classification.service] LLM HTTP ${response.status}`);
      return null;
    }

    const data = await response.json();
    const rawText = isClaude
      ? data?.content?.[0]?.text || ''
      : data?.choices?.[0]?.message?.content || '';

    // Extraire le JSON (peut être entouré de ```json ... ```)
    const jsonMatch = rawText.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return null;

    const parsed = JSON.parse(jsonMatch[0]);
    const urgency = VALID_URGENCIES.includes(parsed.urgency) ? parsed.urgency : 'moyenne';
    const category = VALID_CATEGORIES.includes(parsed.category) ? parsed.category : 'autre';
    const summary = String(parsed.summary || '').slice(0, 200) || transcript.slice(0, 200);

    return { urgency, category, summary };
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Classification par règles (fallback sans LLM).
 */
function _classifyByRules(transcript) {
  const lower = transcript.toLowerCase();

  // Urgence
  let urgency = 'moyenne';
  if (/incendie|feu|flammes|brûle|brule|explosion|gaz|monoxyde|inondation|innondation|eau partout|dégât majeur|degat majeur/.test(lower)) {
    urgency = 'urgence';
  } else if (/pas d'eau|pas de chauffage|plus d'eau|plus de chauffage|froid extrême|froid extreme|électricité coupée|electricite coupee|panne totale|urgence|immédiatement|immediatement|tout de suite/.test(lower)) {
    urgency = 'haute';
  } else if (/fuite|fuit|coule|dégât|degat|bris|brisé|brise|cassé|casse|ne fonctionne plus|marche plus|pu|odeur|moisissure|insecte|vermine|rat|souris/.test(lower)) {
    urgency = 'haute';
  } else if (/réparation|reparation|arrange|répare|repare|check|vérifier|verifier|regarder|inspecter|pas pressé|pas presse/.test(lower)) {
    urgency = 'basse';
  }

  // Catégorie
  let category = 'autre';
  if (/eau|plomb|plomberie|toilette|toilet|douche|bain|baignoire|évier|evier|tuyau|tuyaux|robinet|chauffe-eau|chauffe eau|fuit|fuite|inondation|innondation|drain|égout|egout|pompe/.test(lower)) {
    category = 'plomberie';
  } else if (/électricité|electricite|électrique|electrique|prise|courant|disjoncteur|breaker|panneau|fusible|court-circuit|court circuit|fil|ampoule|lumière|lumiere|interrupteur|chauffe|chauffage|thermostat|fournaise|radiateur|plinthe/.test(lower)) {
    category = 'électrique';
  } else if (/chauffage|chauffer|froid|chaleur|température|temperature|thermostat|fournaise|radiateur|plinthe|climatisation|climatiseur|air climatisé|air climatise/.test(lower)) {
    category = 'chauffage';
  } else if (/mur|plafond|plancher|porte|fenêtre|fenetre|toit|toiture|structure|fissure|craque|trou|infiltration|isolation|moisissure|balcon|escalier|rampe|fondation/.test(lower)) {
    category = 'structure';
  }

  // Résumé
  const sentences = transcript.split(/[.!?]+/).filter(s => s.trim().length > 10);
  const summary = sentences.slice(0, 2).join('. ').trim().slice(0, 200) || transcript.slice(0, 200);

  return { urgency, category, summary };
}

module.exports = { classifyMaintenanceRequest, VALID_URGENCIES, VALID_CATEGORIES };
