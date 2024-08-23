export interface Message {
    role: 'user' | 'assistant',
    content: string,
    status: string,
}