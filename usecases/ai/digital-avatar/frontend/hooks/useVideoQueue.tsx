import { useContext } from 'react';

import { VideoQueueContext, VideoQueueContextProps } from '@/context/VideoQueueContext';


const useVideoQueue: () => VideoQueueContextProps = () => useContext(VideoQueueContext);

export default useVideoQueue;