import type { NextConfig } from "next";
import { withPayload } from '@payloadcms/next/withPayload'

const nextConfig: NextConfig = {
  /* config options here */
  reactStrictMode: false,
  async rewrites() {
    return [
      {
        source: '/api/liveportrait/v1/:slug*',
        destination: `http://${process.env.NEXT_PUBLIC_LIVEPORTRAIT_URL}/v1/:slug*`,
      },
      {
        source: '/api/lipsync/v1/:slug*',
        destination: `http://${process.env.NEXT_PUBLIC_LIPSYNC_URL}/v1/:slug*`,
      },
      {
        source: '/api/stt/v1/:slug*',
        destination: `http://${process.env.NEXT_PUBLIC_STT_URL}/v1/:slug*`,
      },
      {
        source: '/api/tts/v1/:slug*',
        destination: `http://${process.env.NEXT_PUBLIC_TTS_URL}/v1/:slug*`,
      },
      {
        source: '/api/llm/v1/:slug*',
        destination: `http://${process.env.NEXT_PUBLIC_LLM_URL}/v1/:slug*`,
      }
    ]
  }
};

export default withPayload(nextConfig) 
