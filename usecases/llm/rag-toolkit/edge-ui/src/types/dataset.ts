export interface CreateTextBeddingsProps {
  chunkSize: number;
  chunkOverlap: number;
  data: FormData;
}

export interface DocumentProps {
  num_embeddings: number;
  doc_chunks: ChunkProps[];
  current_page: number;
  total_pages: number;
}

export interface ChunkProps {
  ids: string;
  chunk: string;
  source: string;
  page: number;
}