import { FetchAPI } from '@/lib/api';
import { Configs, SelectedPipelineConfig } from '@/types/config';

const STTAPI = new FetchAPI(`http://${process.env.NEXT_PUBLIC_STT_URL ?? "localhost:8014"}`);
const TTSAPI = new FetchAPI(`http://${process.env.NEXT_PUBLIC_TTS_URL ?? "localhost:8013"}`);
const RAGAPI = new FetchAPI(`http://${process.env.NEXT_PUBLIC_LLM_URL ?? "localhost:8012"}`);
const LipsyncAPI = new FetchAPI(`http://${process.env.NEXT_PUBLIC_LIPSYNC_URL ?? "localhost:8011"}`);

export async function GET() {
  try {
    // Fetch configurations from each microservice using fetch
    const [
      sttResponse, 
      ragResponse, 
      ttsResponse, 
      lipsyncResponse
    ] = await Promise.all([
      STTAPI.get('config'),
      RAGAPI.get('config'),
      TTSAPI.get('config'),
      LipsyncAPI.get('config'),
    ]);

    const configResponse: Configs = {
      denoiseStt: sttResponse.data,
      llm: ragResponse.data,
      tts: ttsResponse.data,
      lipsync: lipsyncResponse.data,
    };

    // Return the combined configuration
    return Response.json({ data: configResponse, status: 200 });
  } catch (error) {
    return new Response(`Error fetching configurations: ${error}`, {
      status: 400,
    })
  }
}

// Update configurations
export async function POST(req: Request) {
  const config: Partial<SelectedPipelineConfig> = await req.json();

  try {
    const updatePromises = Object.entries(config).map(([section, sectionConfig]) => {
      switch (section) {
        case 'denoiseStt':
          return STTAPI.post('update_config', sectionConfig);
        case 'llm':
          return RAGAPI.post('update_config', sectionConfig);
        case 'tts':
          return TTSAPI.post('update_config', sectionConfig);
        case 'lipsync':
          return LipsyncAPI.post('update_config', sectionConfig);
        default:
          return Promise.resolve({ status: false, message: `Unknown section: ${section}` });
      }
    });

    const updateResponses = await Promise.all(updatePromises);

    const failedUpdates = updateResponses.filter(response => !response.status);

    if (failedUpdates.length > 0) {
      throw new Error(`Failed to update configurations for the following sections: ${JSON.stringify(failedUpdates)}`);
    }

    // Fetch the updated configurations
    const [
      sttGetConfigResponse,
      ragGetConfigResponse,
      ttsGetConfigResponse,
      lipsyncGetConfigResponse
    ] = await Promise.all([
      STTAPI.get('config'),
      RAGAPI.get('config'),
      TTSAPI.get('config'),
      LipsyncAPI.get('config'),
    ]);

    const configResponse = {
      denoiseStt: sttGetConfigResponse.data,
      llm: ragGetConfigResponse.data,
      tts: ttsGetConfigResponse.data,
      lipsync: lipsyncGetConfigResponse.data,
    };

    // Return the combined configuration
    return Response.json({ data: configResponse, status: 200 });
  } catch (error) {
    return new Response(`Error updating configurations: ${error}`, {
      status: 400,
    });
  }
}