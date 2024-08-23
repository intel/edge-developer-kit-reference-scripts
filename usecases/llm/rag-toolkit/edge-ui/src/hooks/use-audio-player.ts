
import { AudioPlayerContext, type AudioPlayerContextProps } from '@/contexts/AudioPlayerContext';
import { useContext } from 'react';

const useAudioPlayer: () => AudioPlayerContextProps = () => useContext(AudioPlayerContext);

export default useAudioPlayer;