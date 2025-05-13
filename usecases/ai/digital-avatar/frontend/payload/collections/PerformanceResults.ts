import { CollectionConfig } from "payload";

export const PerformanceResults: CollectionConfig = {
    slug: 'performance-results', // The collection slug
    timestamps: true, // Automatically adds createdAt and updatedAt fields
    fields: [
        {
            name: 'denoise',
            type: 'group',
            fields: [
                {
                    name: 'httpLatency',
                    type: 'number',
                    required: false,
                    admin: {
                        description: 'HTTP latency for Denoise in seconds',
                    },
                },
                {
                    name: 'inferenceLatency',
                    type: 'number',
                    required: false,
                    admin: {
                        description: 'Actual inference latency for Denoise in seconds',
                    },
                }
            ],
        },
        {
            name: 'stt',
            type: 'group',
            fields: [
                {
                    name: 'httpLatency',
                    type: 'number',
                    required: false,
                    admin: {
                        description: 'HTTP latency for STT in seconds',
                    },
                },
                {
                    name: 'inferenceLatency',
                    type: 'number',
                    required: false,
                    admin: {
                        description: 'Actual inference latency for STT in seconds',
                    },
                },
            ],
        },
        {
            name: 'llm',
            type: 'group',
            fields: [
                {
                    name: 'totalLatency',
                    type: 'number',
                    required: true,
                    admin: {
                        description: 'Total latency for LLM in seconds',
                    },
                },
                {
                    name: 'ttft',
                    type: 'number',
                    required: true,
                    admin: {
                        description: 'Time to first token for LLM in seconds',
                    },
                },
                {
                    name: 'throughput',
                    type: 'number',
                    required: true,
                    admin: {
                        description: 'Throughput for LLM in tokens per second',
                    },
                },
            ],
        },
        {
            name: 'tts',
            type: 'array',
            fields: [
                {
                    name: 'httpLatency',
                    type: 'number',
                    required: true,
                    admin: {
                        description: 'HTTP latency for TTS in seconds',
                    },
                },
                {
                    name: 'inferenceLatency',
                    type: 'number',
                    required: true,
                    admin: {
                        description: 'Actual inference latency for TTS in seconds',
                    },
                },
                {
                    name: 'metadata',
                    type: 'json',
                    required: false,
                    admin: {
                        description: 'Optional metadata for additional context (e.g., model version, input size)',
                    },
                },
            ],
            admin: {
                description: 'Array of TTS latency measurements',
            },
        },
        {
            name: 'lipsync',
            type: 'array',
            fields: [
                {
                    name: 'httpLatency',
                    type: 'number',
                    required: true,
                    admin: {
                        description: 'HTTP latency for Lipsync in seconds',
                    },
                },
                {
                    name: 'inferenceLatency',
                    type: 'number',
                    required: true,
                    admin: {
                        description: 'Actual inference latency for Lipsync in seconds',
                    },
                },
                {
                    name: 'metadata',
                    type: 'json',
                    required: false,
                    admin: {
                        description: 'Optional metadata for additional context (e.g., model version, input size)',
                    },
                },
            ],
            admin: {
                description: 'Array of Lipsync latency measurements',
            },
        },
        {
            name: 'config',
            type: 'json',
            required: false,
            admin: {
                description: 'Pipeline configurations for the inference',
            },
        },
        {
            name: 'metadata',
            type: 'json',
            required: false,
            admin: {
                description: 'Optional metadata for additional context (e.g., model version, input size)',
            },
        },
    ],
};

export default PerformanceResults;