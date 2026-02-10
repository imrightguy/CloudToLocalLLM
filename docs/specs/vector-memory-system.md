# Specification: Vector Memory System

## 1. Overview
The Vector Memory System is designed to provide high-performance semantic search and long-term memory retrieval for the CloudToLocalLLM ecosystem. This system replaces the legacy SQLite FTS5 (Full-Text Search) implementation with a modern PostgreSQL-based solution utilizing the `pgvector` extension.

## 2. Goals
- **Semantic Retrieval**: Enable search by meaning rather than just keyword matches.
- **Unified Storage**: Provide a shared database accessible by both the OpenClaw Agent and the Flutter Application.
- **Scalability**: Support large-scale memory storage with efficient vector indexing.
- **Development Ease**: Containerized deployment with integrated management tools (pgAdmin).

## 3. Architecture Transition
| Component | Legacy System | New System |
| :--- | :--- | :--- |
| **Engine** | SQLite FTS5 | PostgreSQL 16 + `pgvector` |
| **Search Method** | Keyword (BM25) | Vector Embedding (Cosine Similarity) |
| **Embeddings** | N/A (Manual Parsing) | Gemini-3-Flash (768 Dimensions) |
| **Storage Location** | `/memory.db` (Local File) | Dockerized Persistent Volume |
| **Access Pattern** | Single-user / Local | Multi-service / Networked |

## 4. Infrastructure Configuration (Docker Compose)

To avoid conflicts with default PostgreSQL installations (standard port 5432), the Vector Memory System will utilize **Port 5433**.

### Service Definitions
```yaml
services:
  # PostgreSQL with pgvector extension
  vector-db:
    image: ankane/pgvector:v0.5.1 # Specific pgvector-enabled image
    container_name: cloudtolocalllm-vector-db
    restart: unless-stopped
    ports:
      - "5433:5432" # Host 5433 -> Container 5432
    environment:
      POSTGRES_DB: cloudtolocalllm_memory
      POSTGRES_USER: memory_admin
      POSTGRES_PASSWORD: ${MEMORY_DB_PASSWORD:-memory_pass}
    volumes:
      - memory_pgdata:/var/lib/postgresql/data
      - ./services/postgres/init-vector.sql:/docker-entrypoint-initdb.d/01-init-vector.sql
    networks:
      - cloudllm-network

  # pgAdmin for database management
  pgadmin:
    image: dpage/pgadmin4
    container_name: cloudtolocalllm-pgadmin
    restart: unless-stopped
    ports:
      - "5050:80"
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@cloudtolocalllm.online
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_PASSWORD:-admin_pass}
    depends_on:
      - vector-db
    networks:
      - cloudllm-network

volumes:
  memory_pgdata:
```

## 5. Schema Definition

### 5.1 Extension Initialization
The `pgvector` extension must be enabled on the database:
```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

### 5.2 Table Structure
The system will use a unified `memories` table designed to store text chunks and their corresponding embeddings.

```sql
CREATE TABLE memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    metadata JSONB,
    embedding vector(768), -- Optimized for Gemini-3-Flash
    category VARCHAR(50),
    importance INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### 5.3 Indexing Strategy
For the expected scale and performance requirements, the **HNSW (Hierarchical Navigable Small World)** index is specified over IVFFlat due to its superior query performance and "build once" nature.

```sql
CREATE INDEX idx_memories_embedding_hnsw ON memories 
USING hnsw (embedding vector_cosine_ops);
```

## 6. Embedding Specifications (Gemini-3-Flash)
- **Model**: `google/antigravity-gemini-3-flash` (or equivalent `text-embedding` series).
- **Dimensions**: **768**.
- **Distance Metric**: **Cosine Similarity** (`<=>` operator in pgvector).
- **Batching**: Support for bulk embedding generation to optimize API latency.

## 7. Integration Plan

### 7.1 Agent Integration (MCP Server)
The OpenClaw Agent will interact with the database via a dedicated **Memory MCP Server**.
- **Driver**: `pg` (Node.js PostgreSQL client).
- **Responsibilities**: 
  - Upserting new conversation context.
  - Performing semantic search for RAG (Retrieval-Augmented Generation).
  - Cleaning up old/irrelevant memories.

### 7.2 Flutter App Integration
The Flutter application will access the database through the `api-backend` service to ensure consistent access control and prevent direct DB exposure.
- **Provider**: `postgres` package (for backend-to-DB).
- **Workflow**:
  1. User asks a question in the UI.
  2. Backend generates embedding via Gemini API.
  3. Backend queries `vector-db` for relevant context.
  4. Context is returned to LLM for final response generation.

## 8. Migration Steps
1. **Infrastructure**: Deploy the Docker Compose services on Port 5433.
2. **Schema**: Apply the `memories` table and HNSW index.
3. **Data Ingestion**:
   - Export current SQLite `memory.db` content.
   - Batch process text through Gemini-3-Flash embedding API.
   - Insert records into PostgreSQL.
4. **Validation**: Compare retrieval accuracy between FTS5 (Legacy) and Vector (New).
5. **Cutover**: Update service environment variables to point to the new Postgres instance.

## 9. Conflict Resolution (Port 5432)
To resolve the port 5432 conflict:
- **Primary Proposal**: Standardize on **Port 5433** for the memory-specific vector database. 
- **Secondary Option**: If a centralized database is preferred, upgrade the existing production Postgres instance to include `pgvector` and use schemas/databases to isolate memory from application data. **Port 5433 is recommended for development isolation.**
