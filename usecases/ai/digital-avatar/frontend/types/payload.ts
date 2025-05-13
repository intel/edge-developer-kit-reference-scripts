/**
 * Represents a paginated response for a collection query.
 * All collection find queries are paginated automatically, and the response
 * includes top-level metadata related to pagination, with the returned documents
 * nested within a `docs` array.
 *
 * @template T - The type of the documents in the collection.
 *
 * @property {T[]} docs - Array of documents in the collection.
 * @property {number} totalDocs - Total available documents within the collection.
 * @property {number} limit - Limit query parameter, defaults to 10.
 * @property {number} totalPages - Total pages available, based on the queried limit.
 * @property {number} page - Current page number.
 * @property {number} pagingCounter - Number of the first document on the current page.
 * @property {boolean} hasPrevPage - Indicates if a previous page exists.
 * @property {boolean} hasNextPage - Indicates if a next page exists.
 * @property {number | null} prevPage - Number of the previous page, or `null` if it doesn't exist.
 * @property {number | null} nextPage - Number of the next page, or `null` if it doesn't exist.
 *
 * @example
 * Example response:
 * {
 *   "docs": [
 *     {
 *       "title": "Page Title",
 *       "description": "Some description text",
 *       "priority": 1,
 *       "createdAt": "2020-10-17T01:19:29.858Z",
 *       "updatedAt": "2020-10-17T01:19:29.858Z",
 *       "id": "5f8a46a1dd05db75c3c64760"
 *     }
 *   ],
 *   "totalDocs": 6,
 *   "limit": 1,
 *   "totalPages": 6,
 *   "page": 1,
 *   "pagingCounter": 1,
 *   "hasPrevPage": false,
 *   "hasNextPage": true,
 *   "prevPage": null,
 *   "nextPage": 2
 * }
 */
export interface PayloadResponse<T> {
  docs: T[]
  totalDocs: number
  limit: number
  totalPages: number
  page: number
  pagingCounter: number
  hasPrevPage: boolean
  hasNextPage: boolean
  prevPage: number | null
  nextPage: number | null
}