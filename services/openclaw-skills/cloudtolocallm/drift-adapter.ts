/**
 * Drift Database Adapter
 *
 * Provides access to Drift/SQLite database for personality data.
 * Database is accessed via Tailscale from VPS.
 */

import initSqlJs, { Database } from 'sql.js';

export interface PersonalityProfile {
  agent_id: string;
  formality: number;
  humor: number;
  enthusiasm: number;
  empathy: number;
  evolution_stage: 'curious_explorer' | 'knowledge_seeker' | 'wise_companion' | 'enlightened_guide';
  created_at: string;
  updated_at: string;
}

export interface ConversationMemory {
  id: number;
  agent_id: string;
  timestamp: string;
  user_message: string;
  agent_response: string;
  sentiment_score?: number;
  topics: string[];
}

export interface SelfReflection {
  id: number;
  agent_id: string;
  timestamp: string;
  reflection_type: 'growth' | 'pattern' | 'limitation';
  content: string;
  confidence: number;
}

export class DriftAdapter {
  private db: Database | null = null;
  private dbPath: string;
  private connected: boolean = false;
  private sqlJsReady: boolean = false;
  private SqlJsDatabase: any = null;

  constructor(dbPath: string = '/tmp/drift/personality.db') {
    this.dbPath = dbPath;
  }

  /**
   * Connect to database
   */
  async connect(): Promise<boolean> {
    try {
      // Initialize SQL.js
      if (!this.sqlJsReady) {
        const initSqlJsResult = await initSqlJs();
        this.SqlJsDatabase = initSqlJsResult.Database;
        this.sqlJsReady = true;
      }

      // Read database file
      const fs = await import('fs/promises');
      try {
        const buffer = await fs.readFile(this.dbPath);
        this.db = new this.SqlJsDatabase(buffer);
      } catch {
        // File doesn't exist, create in-memory database
        this.db = new this.SqlJsDatabase();
      }

      this.connected = true;
      return true;
    } catch (error) {
      console.error('[DriftAdapter] Failed to connect:', error);
      return false;
    }
  }

  /**
   * Disconnect from database
   */
  disconnect(): void {
    if (this.db) {
      this.db.close();
      this.db = null;
      this.connected = false;
    }
  }

  /**
   * Check if connected
   */
  isConnected(): boolean {
    return this.connected && this.db !== null;
  }

  /**
   * Load personality profile for agent
   */
  loadPersonality(agentId: string): PersonalityProfile | null {
    if (!this.db) {
      throw new Error('Database not connected');
    }

    try {
      const stmt = this.db.prepare('SELECT * FROM personality_profiles WHERE agent_id = :agentId');
      const result = stmt.getAsObject({ ':agentId': agentId }) as any;

      if (!result || Object.keys(result).length === 0) {
        return null;
      }

      return {
        agent_id: result.agent_id,
        formality: result.formality,
        humor: result.humor,
        enthusiasm: result.enthusiasm,
        empathy: result.empathy,
        evolution_stage: result.evolution_stage,
        created_at: result.created_at,
        updated_at: result.updated_at,
      };
    } catch (error) {
      console.error('[DriftAdapter] Failed to load personality:', error);
      return null;
    }
  }

  /**
   * Create or update personality profile
   */
  savePersonality(profile: PersonalityProfile): boolean {
    if (!this.db) {
      throw new Error('Database not connected');
    }

    try {
      const now = new Date().toISOString();

      const existing = this.loadPersonality(profile.agent_id);

      if (existing) {
        // Update
        this.db.run(`
          UPDATE personality_profiles
          SET formality = :formality, humor = :humor, enthusiasm = :enthusiasm, empathy = :empathy,
              evolution_stage = :evolution_stage, updated_at = :updated_at
          WHERE agent_id = :agent_id
        `, {
          ':formality': profile.formality,
          ':humor': profile.humor,
          ':enthusiasm': profile.enthusiasm,
          ':empathy': profile.empathy,
          ':evolution_stage': profile.evolution_stage,
          ':updated_at': now,
          ':agent_id': profile.agent_id,
        });
      } else {
        // Insert
        this.db.run(`
          INSERT INTO personality_profiles
          (agent_id, formality, humor, enthusiasm, empathy, evolution_stage, created_at, updated_at)
          VALUES (:agent_id, :formality, :humor, :enthusiasm, :empathy, :evolution_stage, :created_at, :updated_at)
        `, {
          ':agent_id': profile.agent_id,
          ':formality': profile.formality,
          ':humor': profile.humor,
          ':enthusiasm': profile.enthusiasm,
          ':empathy': profile.empathy,
          ':evolution_stage': profile.evolution_stage,
          ':created_at': now,
          ':updated_at': now,
        });
      }

      return true;
    } catch (error) {
      console.error('[DriftAdapter] Failed to save personality:', error);
      return false;
    }
  }

  /**
   * Store conversation memory
   */
  storeMemory(memory: Omit<ConversationMemory, 'id'>): boolean {
    if (!this.db) {
      throw new Error('Database not connected');
    }

    try {
      this.db.run(`
        INSERT INTO conversation_memories
        (agent_id, timestamp, user_message, agent_response, sentiment_score, topics)
        VALUES (:agent_id, :timestamp, :user_message, :agent_response, :sentiment_score, :topics)
      `, {
        ':agent_id': memory.agent_id,
        ':timestamp': memory.timestamp,
        ':user_message': memory.user_message,
        ':agent_response': memory.agent_response,
        ':sentiment_score': memory.sentiment_score ?? null,
        ':topics': JSON.stringify(memory.topics),
      });

      return true;
    } catch (error) {
      console.error('[DriftAdapter] Failed to store memory:', error);
      return false;
    }
  }

  /**
   * Get recent conversations for context
   */
  getRecentMemories(agentId: string, limit: number = 10): ConversationMemory[] {
    if (!this.db) {
      throw new Error('Database not connected');
    }

    try {
      const stmt = this.db.prepare(`
        SELECT * FROM conversation_memories
        WHERE agent_id = :agent_id
        ORDER BY timestamp DESC
        LIMIT :limit
      `);

      const results: any[] = [];
      stmt.bind({ ':agent_id': agentId, ':limit': limit });
      while (stmt.step()) {
        results.push(stmt.getAsObject());
      }

      return results.map(row => ({
        id: row.id,
        agent_id: row.agent_id,
        timestamp: row.timestamp,
        user_message: row.user_message,
        agent_response: row.agent_response,
        sentiment_score: row.sentiment_score,
        topics: JSON.parse(row.topics || '[]'),
      }));
    } catch (error) {
      console.error('[DriftAdapter] Failed to get memories:', error);
      return [];
    }
  }

  /**
   * Store self-reflection
   */
  storeReflection(reflection: Omit<SelfReflection, 'id'>): boolean {
    if (!this.db) {
      throw new Error('Database not connected');
    }

    try {
      this.db.run(`
        INSERT INTO self_reflections
        (agent_id, timestamp, reflection_type, content, confidence)
        VALUES (:agent_id, :timestamp, :reflection_type, :content, :confidence)
      `, {
        ':agent_id': reflection.agent_id,
        ':timestamp': reflection.timestamp,
        ':reflection_type': reflection.reflection_type,
        ':content': reflection.content,
        ':confidence': reflection.confidence,
      });

      return true;
    } catch (error) {
      console.error('[DriftAdapter] Failed to store reflection:', error);
      return false;
    }
  }

  /**
   * Get recent reflections for evolution assessment
   */
  getRecentReflections(agentId: string, limit: number = 20): SelfReflection[] {
    if (!this.db) {
      throw new Error('Database not connected');
    }

    try {
      const stmt = this.db.prepare(`
        SELECT * FROM self_reflections
        WHERE agent_id = :agent_id
        ORDER BY timestamp DESC
        LIMIT :limit
      `);

      const results: any[] = [];
      stmt.bind({ ':agent_id': agentId, ':limit': limit });
      while (stmt.step()) {
        results.push(stmt.getAsObject());
      }

      return results.map(row => ({
        id: row.id,
        agent_id: row.agent_id,
        timestamp: row.timestamp,
        reflection_type: row.reflection_type,
        content: row.content,
        confidence: row.confidence,
      }));
    } catch (error) {
      console.error('[DriftAdapter] Failed to get reflections:', error);
      return [];
    }
  }

  /**
   * Get conversation statistics for evolution assessment
   */
  getConversationStats(agentId: string): {
    totalConversations: number;
    uniqueTopics: number;
    avgSentiment: number;
    depthScore: number;
  } {
    if (!this.db) {
      throw new Error('Database not connected');
    }

    try {
      const totalStmt = this.db.prepare(`
        SELECT COUNT(*) as count FROM conversation_memories
        WHERE agent_id = :agent_id
      `);
      totalStmt.bind({ ':agent_id': agentId });
      const totalResult = totalStmt.getAsObject() as any;
      const total = totalResult.count ?? 0;

      // For simplicity, skip complex topic counting with json_each in sql.js
      // Return 0 for unique topics in this simplified version
      const uniqueTopics = 0;

      const sentimentStmt = this.db.prepare(`
        SELECT AVG(sentiment_score) as avg
        FROM conversation_memories
        WHERE agent_id = :agent_id AND sentiment_score IS NOT NULL
      `);
      sentimentStmt.bind({ ':agent_id': agentId });
      const sentimentResult = sentimentStmt.getAsObject() as any;
      const avgSentiment = sentimentResult.avg ?? 0.5;

      // Depth score: average conversation length and topic diversity
      const depthStmt = this.db.prepare(`
        SELECT LENGTH(user_message) + LENGTH(agent_response) as depth
        FROM conversation_memories
        WHERE agent_id = :agent_id
        ORDER BY timestamp DESC
        LIMIT 50
      `);
      depthStmt.bind({ ':agent_id': agentId });

      const depths: number[] = [];
      while (depthStmt.step()) {
        const row = depthStmt.getAsObject() as any;
        depths.push(row.depth ?? 0);
      }

      const avgDepth = depths.length > 0
        ? depths.reduce((sum, d) => sum + d, 0) / depths.length
        : 0;

      return {
        totalConversations: total,
        uniqueTopics,
        avgSentiment,
        depthScore: Math.min(avgDepth / 1000, 1), // Normalize to 0-1
      };
    } catch (error) {
      console.error('[DriftAdapter] Failed to get stats:', error);
      return {
        totalConversations: 0,
        uniqueTopics: 0,
        avgSentiment: 0.5,
        depthScore: 0,
      };
    }
  }
}
