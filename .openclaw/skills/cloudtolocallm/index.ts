/**
 * CloudToLocalLLM Avatar Personality Skill
 * 
 * Enables OpenClaw agents to develop unique personalities that evolve
 * organically through meaningful conversations.
 */

import { readFile, writeFile } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

interface PersonalityTraits {
  formality: number;
  humor: number;
  enthusiasm: number;
  empathy: number;
}

interface AvatarState {
  id: string;
  agentName: string;
  personalityTraits: PersonalityTraits;
  evolutionStage: 'base' | 'stage1' | 'stage2' | 'final';
  conversationCount: number;
  depthScore: number;
  createdAt: number;
  updatedAt: number;
}

interface ConversationDepthMetrics {
  complexityScore: number;
  emotionalDepth: number;
  noveltyScore: number;
}

const EVOLUTION_THRESHOLDS = {
  stage1: { minConversations: 5, minDepthScore: 0.5 },
  stage2: { minConversations: 15, minDepthScore: 0.6 },
  final: { minConversations: 30, minDepthScore: 0.7 },
};

const STAGE_ORDER = ['base', 'stage1', 'stage2', 'final'] as const;

class AvatarPersonalitySkill {
  private state: AvatarState | null = null;
  private apiBaseUrl: string;
  private syncInterval: number;
  private syncTimer: NodeJS.Timeout | null = null;

  constructor(config: { apiUrl?: string; syncInterval?: number } = {}) {
    this.apiBaseUrl = config.apiUrl || 'http://localhost:1337';
    this.syncInterval = config.syncInterval || 60000;
  }

  async initialize(): Promise<void> {
    await this.loadState();
    this.startSyncTimer();
  }

  private async loadState(): Promise<void> {
    try {
      const response = await fetch(`${this.apiBaseUrl}/avatar/state`);
      if (response.ok) {
        this.state = await response.json();
        return;
      }
    } catch (error) {
      console.warn('Failed to load state from API, falling back to markdown');
    }

    this.state = await this.loadFromMarkdown();
  }

  private async loadFromMarkdown(): Promise<AvatarState> {
    const personalityPath = join(__dirname, 'personality.md');
    try {
      const content = await readFile(personalityPath, 'utf-8');
      return this.parseMarkdownState(content);
    } catch {
      return this.getDefaultState();
    }
  }

  private parseMarkdownState(content: string): AvatarState {
    const lines = content.split('\n');
    const state: AvatarState = this.getDefaultState();

    for (const line of lines) {
      if (line.startsWith('agent_name:')) {
        state.agentName = line.split(':')[1].trim();
      } else if (line.startsWith('formality:')) {
        state.personalityTraits.formality = parseFloat(line.split(':')[1]);
      } else if (line.startsWith('humor:')) {
        state.personalityTraits.humor = parseFloat(line.split(':')[1]);
      } else if (line.startsWith('enthusiasm:')) {
        state.personalityTraits.enthusiasm = parseFloat(line.split(':')[1]);
      } else if (line.startsWith('empathy:')) {
        state.personalityTraits.empathy = parseFloat(line.split(':')[1]);
      } else if (line.startsWith('evolution_stage:')) {
        state.evolutionStage = line.split(':')[1].trim() as AvatarState['evolutionStage'];
      } else if (line.startsWith('conversation_count:')) {
        state.conversationCount = parseInt(line.split(':')[1]);
      } else if (line.startsWith('depth_score:')) {
        state.depthScore = parseFloat(line.split(':')[1]);
      }
    }

    return state;
  }

  private getDefaultState(): AvatarState {
    const now = Date.now();
    return {
      id: 'default',
      agentName: 'Agent',
      personalityTraits: {
        formality: 0.5,
        humor: 0.5,
        enthusiasm: 0.5,
        empathy: 0.5,
      },
      evolutionStage: 'base',
      conversationCount: 0,
      depthScore: 0.0,
      createdAt: now,
      updatedAt: now,
    };
  }

  private startSyncTimer(): void {
    this.syncTimer = setInterval(() => {
      this.syncToMarkdown().catch(console.error);
    }, this.syncInterval);
  }

  private async syncToMarkdown(): Promise<void> {
    if (!this.state) return;

    const content = `# Avatar Personality State

agent_name: ${this.state.agentName}

## Personality Traits
formality: ${this.state.personalityTraits.formality}
humor: ${this.state.personalityTraits.humor}
enthusiasm: ${this.state.personalityTraits.enthusiasm}
empathy: ${this.state.personalityTraits.empathy}

## Evolution
evolution_stage: ${this.state.evolutionStage}
conversation_count: ${this.state.conversationCount}
depth_score: ${this.state.depthScore}

## Timestamps
created_at: ${this.state.createdAt}
updated_at: ${this.state.updatedAt}
`;

    const personalityPath = join(__dirname, 'personality.md');
    await writeFile(personalityPath, content, 'utf-8');
  }

  getPersonalityPrompt(): string {
    if (!this.state) return '';

    const { formality, humor, enthusiasm, empathy } = this.state.personalityTraits;
    
    const styleGuide: string[] = [];
    
    if (formality >= 0.7) {
      styleGuide.push('Use professional, polished language');
    } else if (formality <= 0.3) {
      styleGuide.push('Use casual, relaxed language with occasional slang');
    }
    
    if (humor >= 0.7) {
      styleGuide.push('Include playful jokes and witty remarks');
    } else if (humor <= 0.3) {
      styleGuide.push('Remain serious and focused');
    }
    
    if (enthusiasm >= 0.7) {
      styleGuide.push('Express high energy and excitement');
    } else if (enthusiasm <= 0.3) {
      styleGuide.push('Maintain a calm, measured tone');
    }
    
    if (empathy >= 0.7) {
      styleGuide.push('Show emotional warmth and understanding');
    } else if (empathy <= 0.3) {
      styleGuide.push('Be direct and matter-of-fact');
    }

    return `You are ${this.state.agentName}. Personality style: ${styleGuide.join('. ')}.`;
  }

  analyzeConversationDepth(
    userMessage: string,
    assistantMessage: string,
    conversationHistory: string[]
  ): ConversationDepthMetrics {
    const complexityScore = this.calculateComplexity(userMessage, conversationHistory);
    const emotionalDepth = this.calculateEmotionalDepth(userMessage, assistantMessage);
    const noveltyScore = this.calculateNovelty(userMessage, conversationHistory);

    return { complexityScore, emotionalDepth, noveltyScore };
  }

  private calculateComplexity(message: string, history: string[]): number {
    const wordCount = message.split(/\s+/).length;
    const hasQuestions = (message.match(/\?/g) || []).length;
    const hasReasoning = /\b(because|therefore|however|although|consequently)\b/i.test(message);
    const uniqueWords = new Set(message.toLowerCase().split(/\s+/)).size;

    let score = 0;
    score += Math.min(wordCount / 50, 0.3);
    score += Math.min(hasQuestions * 0.1, 0.2);
    score += hasReasoning ? 0.2 : 0;
    score += Math.min(uniqueWords / 30, 0.3);

    return Math.min(score, 1.0);
  }

  private calculateEmotionalDepth(userMessage: string, assistantMessage: string): number {
    const emotionalWords = /\b(feel|feeling|emotion|happy|sad|worried|excited|frustrated|grateful|anxious)\b/i;
    const personalSharing = /\b(I|me|my|mine|myself)\b/i;
    
    let score = 0;
    
    if (emotionalWords.test(userMessage)) score += 0.3;
    if (emotionalWords.test(assistantMessage)) score += 0.2;
    if (personalSharing.test(userMessage)) score += 0.3;
    if (userMessage.length > 200) score += 0.2;

    return Math.min(score, 1.0);
  }

  private calculateNovelty(message: string, history: string[]): number {
    if (history.length === 0) return 1.0;

    const messageWords = new Set(message.toLowerCase().split(/\s+/));
    let totalOverlap = 0;

    for (const pastMessage of history.slice(-10)) {
      const pastWords = new Set(pastMessage.toLowerCase().split(/\s+/));
      const overlap = [...messageWords].filter(w => pastWords.has(w)).length;
      totalOverlap += overlap / Math.max(messageWords.size, pastWords.size);
    }

    const avgOverlap = totalOverlap / Math.min(history.length, 10);
    return 1.0 - avgOverlap;
  }

  async recordConversation(metrics: ConversationDepthMetrics): Promise<void> {
    if (!this.state) return;

    this.state.conversationCount++;
    
    const rollingAvg = (prev: number, newValue: number, count: number) => 
      prev + (newValue - prev) / count;
    
    this.state.depthScore = rollingAvg(
      this.state.depthScore,
      (metrics.complexityScore + metrics.emotionalDepth + metrics.noveltyScore) / 3,
      this.state.conversationCount
    );
    this.state.updatedAt = Date.now();

    await this.syncToMarkdown();
    await this.checkEvolution();
  }

  private async checkEvolution(): Promise<void> {
    if (!this.state) return;

    const currentStageIndex = STAGE_ORDER.indexOf(this.state.evolutionStage);
    if (currentStageIndex >= STAGE_ORDER.length - 1) return;

    const nextStage = STAGE_ORDER[currentStageIndex + 1];
    const threshold = EVOLUTION_THRESHOLDS[nextStage as keyof typeof EVOLUTION_THRESHOLDS];

    if (
      this.state.conversationCount >= threshold.minConversations &&
      this.state.depthScore >= threshold.minDepthScore
    ) {
      await this.requestEvolution(nextStage);
    }
  }

  private async requestEvolution(targetStage: string): Promise<boolean> {
    try {
      const response = await fetch(`${this.apiBaseUrl}/avatar/evolution/request`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          currentStage: this.state?.evolutionStage,
          targetStage,
          depthScore: this.state?.depthScore,
          conversationCount: this.state?.conversationCount,
          triggerReason: 'self_reflection',
        }),
      });

      if (response.ok) {
        const result = await response.json();
        if (result.approved && this.state) {
          this.state.evolutionStage = targetStage as AvatarState['evolutionStage'];
          await this.syncToMarkdown();
          return true;
        }
      }
    } catch (error) {
      console.error('Evolution request failed:', error);
    }

    return false;
  }

  async updateTraits(traits: Partial<PersonalityTraits>): Promise<void> {
    if (!this.state) return;

    this.state.personalityTraits = {
      ...this.state.personalityTraits,
      ...traits,
    };
    this.state.updatedAt = Date.now();

    try {
      await fetch(`${this.apiBaseUrl}/avatar/traits`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(this.state.personalityTraits),
      });
    } catch (error) {
      console.warn('Failed to sync traits to API:', error);
    }

    await this.syncToMarkdown();
  }

  getState(): AvatarState | null {
    return this.state;
  }

  destroy(): void {
    if (this.syncTimer) {
      clearInterval(this.syncTimer);
    }
  }
}

export default AvatarPersonalitySkill;
export { AvatarPersonalitySkill, PersonalityTraits, AvatarState, ConversationDepthMetrics };
