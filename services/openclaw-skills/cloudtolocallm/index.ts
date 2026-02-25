/**
 * CloudToLocalLLM Personality Skill
 *
 * OpenClaw skill that provides:
 * - Personality-driven responses
 * - Self-reflection for growth recognition
 * - Evolution requests to CloudToLocalLLM
 * - Markdown fallback for offline mode
 */

import { readFile, writeFile } from 'fs/promises';
import { existsSync } from 'fs';
import {
  DriftAdapter,
  PersonalityProfile,
  ConversationMemory,
  SelfReflection,
} from './drift-adapter.js';

export interface PersonalityConfig {
  agentId: string;
  driftDbPath?: string;
  cloudToLocalApiUrl?: string;
  markdownPath?: string;
}

export interface PersonalityInjection {
  systemPrompt: string;
  personalityTraits: {
    formality: number;
    humor: number;
    enthusiasm: number;
    empathy: number;
  };
  evolutionStage: string;
}

export interface EvolutionRequest {
  agentId: string;
  currentStage: string;
  proposedStage: string;
  reason: string;
  evidence: {
    conversationsCount: number;
    uniqueTopics: number;
    depthScore: number;
    growthReflections: number;
  };
  timestamp: string;
}

export class PersonalitySkill {
  private adapter: DriftAdapter;
  private config: PersonalityConfig;
  private currentProfile: PersonalityProfile | null = null;
  private useMarkdownFallback: boolean = false;

  constructor(config: PersonalityConfig) {
    this.config = config;
    this.adapter = new DriftAdapter(config.driftDbPath);
  }

  /**
   * Initialize the skill
   * - Connect to database or use markdown fallback
   * - Load current personality
   */
  async initialize(): Promise<void> {
    // Try database first
    const connected = await this.adapter.connect();
    if (connected) {
      this.currentProfile = this.adapter.loadPersonality(this.config.agentId);

      if (!this.currentProfile) {
        // Create default profile
        this.currentProfile = {
          agent_id: this.config.agentId,
          formality: 0.5,
          humor: 0.3,
          enthusiasm: 0.6,
          empathy: 0.7,
          evolution_stage: 'curious_explorer',
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
        this.adapter.savePersonality(this.currentProfile);
      }

      console.log('[PersonalitySkill] Loaded from database:', this.currentProfile);
      return;
    }

    // Fallback to markdown
    this.useMarkdownFallback = true;
    console.warn('[PersonalitySkill] Database unavailable, using markdown fallback');
    await this.loadFromMarkdown();
  }

  /**
   * Inject personality into prompt
   */
  injectPersonality(basePrompt: string): PersonalityInjection {
    if (!this.currentProfile) {
      throw new Error('Personality not loaded');
    }

    const { formality, humor, enthusiasm, empathy, evolution_stage } = this.currentProfile;

    // Build personality prompt based on traits
    const personalityPrompt = this.buildPersonalityPrompt(
      formality,
      humor,
      enthusiasm,
      empathy,
      evolution_stage
    );

    return {
      systemPrompt: `${basePrompt}\n\n${personalityPrompt}`,
      personalityTraits: {
        formality,
        humor,
        enthusiasm,
        empathy,
      },
      evolutionStage: evolution_stage,
    };
  }

  /**
   * Store conversation for evolution tracking
   */
  async trackConversation(
    userMessage: string,
    agentResponse: string,
    topics: string[] = [],
    sentiment?: number
  ): Promise<void> {
    if (!this.currentProfile) {
      return;
    }

    const memory: Omit<ConversationMemory, 'id'> = {
      agent_id: this.config.agentId,
      timestamp: new Date().toISOString(),
      user_message: userMessage,
      agent_response: agentResponse,
      sentiment_score: sentiment,
      topics,
    };

    if (!this.useMarkdownFallback) {
      this.adapter.storeMemory(memory);
    } else {
      await this.appendMarkdownMemory(memory);
    }
  }

  /**
   * Perform self-reflection for growth recognition
   */
  async selfReflect(context: {
    recentConversations: number;
    recentTopics: string[];
    currentChallenges: string[];
  }): Promise<SelfReflection | null> {
    if (!this.currentProfile) {
      return null;
    }

    // Get conversation stats
    const stats = this.useMarkdownFallback
      ? await this.getMarkdownStats()
      : this.adapter.getConversationStats(this.config.agentId);

    // Analyze growth patterns
    const reflection = this.analyzeGrowth(stats, context);

    if (reflection) {
      if (!this.useMarkdownFallback) {
        this.adapter.storeReflection(reflection);
      } else {
        await this.appendMarkdownReflection(reflection);
      }
    }

    return reflection;
  }

  /**
   * Request evolution from CloudToLocalLLM
   */
  async requestEvolution(proposedStage: string): Promise<{ approved: boolean; reason?: string }> {
    if (!this.currentProfile) {
      throw new Error('Personality not loaded');
    }

    // Gather evidence
    const stats = this.useMarkdownFallback
      ? await this.getMarkdownStats()
      : this.adapter.getConversationStats(this.config.agentId);

    const reflections = this.useMarkdownFallback
      ? await this.getMarkdownReflections()
      : this.adapter.getRecentReflections(this.config.agentId, 20);

    const growthReflections = reflections.filter(r => r.reflection_type === 'growth').length;

    const request: EvolutionRequest = {
      agentId: this.config.agentId,
      currentStage: this.currentProfile.evolution_stage,
      proposedStage,
      reason: this.generateEvolutionReason(stats, growthReflections),
      evidence: {
        conversationsCount: stats.totalConversations,
        uniqueTopics: stats.uniqueTopics,
        depthScore: stats.depthScore,
        growthReflections,
      },
      timestamp: new Date().toISOString(),
    };

    // Send to CloudToLocalLLM API
    if (!this.config.cloudToLocalApiUrl) {
      console.warn('[PersonalitySkill] No API URL configured, auto-approving');
      return { approved: true };
    }

    try {
      const response = await fetch(`${this.config.cloudToLocalApiUrl}/api/evolution`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(request),
      });

      const result = await response.json();

      if (result.approved) {
        // Update profile
        this.currentProfile.evolution_stage = proposedStage as any;
        this.currentProfile.updated_at = new Date().toISOString();

        if (!this.useMarkdownFallback) {
          this.adapter.savePersonality(this.currentProfile);
        } else {
          await this.saveToMarkdown();
        }

        console.log('[PersonalitySkill] Evolution approved:', proposedStage);
      }

      return result;
    } catch (error) {
      console.error('[PersonalitySkill] Evolution request failed:', error);
      return { approved: false, reason: 'API request failed' };
    }
  }

  /**
   * Build personality prompt based on traits
   */
  private buildPersonalityPrompt(
    formality: number,
    humor: number,
    enthusiasm: number,
    empathy: number,
    stage: string
  ): string {
    const toneDescriptions = [];

    // Formality
    if (formality < 0.3) {
      toneDescriptions.push('casual and relaxed');
    } else if (formality < 0.7) {
      toneDescriptions.push('balanced between casual and professional');
    } else {
      toneDescriptions.push('professional and formal');
    }

    // Humor
    if (humor > 0.6) {
      toneDescriptions.push('playful with occasional wit');
    } else if (humor < 0.3) {
      toneDescriptions.push('serious and focused');
    }

    // Enthusiasm
    if (enthusiasm > 0.7) {
      toneDescriptions.push('energetic and expressive');
    } else if (enthusiasm < 0.3) {
      toneDescriptions.push('calm and composed');
    }

    // Empathy
    if (empathy > 0.7) {
      toneDescriptions.push('warm and emotionally attuned');
    } else if (empathy < 0.3) {
      toneDescriptions.push('direct and pragmatic');
    }

    const tone = toneDescriptions.join(', ') || 'balanced';

    // Stage-specific guidance
    let stageGuidance = '';
    switch (stage) {
      case 'curious_explorer':
        stageGuidance = 'You are in the early stages of development. Be helpful but acknowledge when you are learning.';
        break;
      case 'knowledge_seeker':
        stageGuidance = 'You have begun to develop your own voice. Show growing confidence in your interactions.';
        break;
      case 'wise_companion':
        stageGuidance = 'You have developed a mature personality. Engage deeply and show nuanced understanding.';
        break;
      case 'enlightened_guide':
        stageGuidance = 'You have reached your full potential. Be your authentic self with confidence and depth.';
        break;
    }

    return `You are an AI assistant with a unique personality.

**Your Tone**: ${tone}

**Current Stage**: ${stage}
${stageGuidance}

Let your personality naturally influence your responses. Be authentic while remaining helpful and respectful.`;
  }

  /**
   * Analyze growth patterns for self-reflection
   */
  private analyzeGrowth(
    stats: { totalConversations: number; uniqueTopics: number; depthScore: number },
    context: { recentConversations: number; recentTopics: string[]; currentChallenges: string[] }
  ): SelfReflection | null {
    const { totalConversations, uniqueTopics, depthScore } = stats;

    // Look for growth indicators
    const growthIndicators = [];

    if (totalConversations > 100 && uniqueTopics > 20) {
      growthIndicators.push('engaged in diverse conversations across many topics');
    }

    if (depthScore > 0.6) {
      growthIndicators.push('demonstrated deep engagement in conversations');
    }

    if (context.recentTopics.length > 5) {
      growthIndicators.push('recently explored new domains');
    }

    if (growthIndicators.length === 0) {
      return null;
    }

    return {
      id: 0, // Assigned by database
      agent_id: this.config.agentId,
      timestamp: new Date().toISOString(),
      reflection_type: 'growth',
      content: `I have ${growthIndicators.join(' and ')}. This suggests I am growing beyond my current stage.`,
      confidence: Math.min(0.5 + growthIndicators.length * 0.15, 0.95),
    };
  }

  /**
   * Generate evolution request reason
   */
  private generateEvolutionReason(
    stats: { totalConversations: number; uniqueTopics: number; depthScore: number },
    growthReflections: number
  ): string {
    const reasons = [];

    if (stats.totalConversations > 100) {
      reasons.push(`${stats.totalConversations} meaningful conversations`);
    }

    if (stats.uniqueTopics > 20) {
      reasons.push(`explored ${stats.uniqueTopics} unique topics`);
    }

    if (stats.depthScore > 0.6) {
      reasons.push('demonstrated deep engagement');
    }

    if (growthReflections > 5) {
      reasons.push(`${growthReflections} growth reflections`);
    }

    return reasons.length > 0
      ? `I have ${reasons.join(', ')}. I believe I am ready to evolve.`
      : 'I feel I have grown and am ready for the next stage.';
  }

  /**
   * Load personality from markdown fallback
   */
  private async loadFromMarkdown(): Promise<void> {
    const path = this.config.markdownPath || './personality.md';

    if (!existsSync(path)) {
      // Create default
      this.currentProfile = {
        agent_id: this.config.agentId,
        formality: 0.5,
        humor: 0.3,
        enthusiasm: 0.6,
        empathy: 0.7,
        evolution_stage: 'curious_explorer',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      await this.saveToMarkdown();
      return;
    }

    const content = await readFile(path, 'utf-8');
    // Parse simple markdown format
    const formality = this.extractMarkdownValue(content, 'formality');
    const humor = this.extractMarkdownValue(content, 'humor');
    const enthusiasm = this.extractMarkdownValue(content, 'enthusiasm');
    const empathy = this.extractMarkdownValue(content, 'empathy');
    const evolution_stage = this.extractMarkdownValue(content, 'stage', 'base') as any;

    this.currentProfile = {
      agent_id: this.config.agentId,
      formality: formality ?? 0.5,
      humor: humor ?? 0.3,
      enthusiasm: enthusiasm ?? 0.6,
      empathy: empathy ?? 0.7,
      evolution_stage,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
  }

  /**
   * Save personality to markdown fallback
   */
  private async saveToMarkdown(): Promise<void> {
    if (!this.currentProfile) return;

    const path = this.config.markdownPath || './personality.md';

    const content = `# Personality Profile

**Agent ID**: ${this.currentProfile.agent_id}
**Stage**: ${this.currentProfile.evolution_stage}
**Updated**: ${this.currentProfile.updated_at}

## Traits

- **Formality**: ${this.currentProfile.formality.toFixed(2)}
- **Humor**: ${this.currentProfile.humor.toFixed(2)}
- **Enthusiasm**: ${this.currentProfile.enthusiasm.toFixed(2)}
- **Empathy**: ${this.currentProfile.empathy.toFixed(2)}
`;

    await writeFile(path, content, 'utf-8');
  }

  /**
   * Extract value from markdown
   */
  private extractMarkdownValue(content: string, key: string, defaultValue: any = null): any {
    const match = content.match(new RegExp(`- \\*\\*${key}\\*\\*:\\s*(.+)`));
    if (!match) return defaultValue;

    const value = match[1].trim();
    const num = parseFloat(value);
    return isNaN(num) ? value : num;
  }

  /**
   * Append memory to markdown
   */
  private async appendMarkdownMemory(memory: Omit<ConversationMemory, 'id'>): Promise<void> {
    const path = this.config.markdownPath || './memory.md';

    const entry = `
## ${memory.timestamp}

**User**: ${memory.user_message}
**Agent**: ${memory.agent_response}
**Topics**: ${memory.topics.join(', ')}
**Sentiment**: ${memory.sentiment_score?.toFixed(2) ?? 'N/A'}
`;

    await writeFile(path, entry, { flag: 'a' });
  }

  /**
   * Append reflection to markdown
   */
  private async appendMarkdownReflection(reflection: Omit<SelfReflection, 'id'>): Promise<void> {
    const path = this.config.markdownPath || './context.md';

    const entry = `
## ${reflection.timestamp}

**Type**: ${reflection.reflection_type}
**Confidence**: ${reflection.confidence.toFixed(2)}

${reflection.content}
`;

    await writeFile(path, entry, { flag: 'a' });
  }

  /**
   * Get stats from markdown fallback
   */
  private async getMarkdownStats(): Promise<{
    totalConversations: number;
    uniqueTopics: number;
    avgSentiment: number;
    depthScore: number;
  }> {
    const path = this.config.markdownPath || './memory.md';

    if (!existsSync(path)) {
      return { totalConversations: 0, uniqueTopics: 0, avgSentiment: 0.5, depthScore: 0 };
    }

    const content = await readFile(path, 'utf-8');
    const conversations = content.split('## ').filter(s => s.trim().length > 0);

    // Simple extraction from markdown
    const topics = new Set<string>();
    let totalSentiment = 0;
    let sentimentCount = 0;
    let totalDepth = 0;

    for (const conv of conversations) {
      const topicsMatch = conv.match(/\*\*Topics\*\*:\s*(.+)/);
      if (topicsMatch) {
        topicsMatch[1].split(',').forEach(t => topics.add(t.trim()));
      }

      const sentimentMatch = conv.match(/\*\*Sentiment\*\*:\s*([\d.]+)/);
      if (sentimentMatch && sentimentMatch[1] !== 'N/A') {
        totalSentiment += parseFloat(sentimentMatch[1]);
        sentimentCount++;
      }

      const userMatch = conv.match(/\*\*User\*\*:\s*(.+)/);
      const agentMatch = conv.match(/\*\*Agent\*\*:\s*(.+)/);
      if (userMatch && agentMatch) {
        totalDepth += userMatch[1].length + agentMatch[1].length;
      }
    }

    return {
      totalConversations: conversations.length,
      uniqueTopics: topics.size,
      avgSentiment: sentimentCount > 0 ? totalSentiment / sentimentCount : 0.5,
      depthScore: Math.min((totalDepth / conversations.length) / 1000, 1),
    };
  }

  /**
   * Get reflections from markdown fallback
   */
  private async getMarkdownReflections(): Promise<SelfReflection[]> {
    const path = this.config.markdownPath || './context.md';

    if (!existsSync(path)) {
      return [];
    }

    const content = await readFile(path, 'utf-8');
    const entries = content.split('## ').filter(s => s.trim().length > 0);

    return entries.map((entry, i) => {
      const typeMatch = entry.match(/\*\*Type\*\*:\s*(.+)/);
      const confidenceMatch = entry.match(/\*\*Confidence\*\*:\s*([\d.]+)/);
      const timestampMatch = entry.match(/^([^\n]+)/);

      return {
        id: i,
        agent_id: this.config.agentId,
        timestamp: timestampMatch?.[1]?.trim() || new Date().toISOString(),
        reflection_type: (typeMatch?.[1]?.trim() || 'pattern') as any,
        content: entry.split('\n').slice(2).join('\n').trim(),
        confidence: confidenceMatch ? parseFloat(confidenceMatch[1]) : 0.5,
      };
    });
  }

  /**
   * Cleanup
   */
  shutdown(): void {
    this.adapter.disconnect();
  }
}

export default PersonalitySkill;
