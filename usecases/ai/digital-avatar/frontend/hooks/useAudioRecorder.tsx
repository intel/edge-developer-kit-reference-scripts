// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useCallback, useEffect, useRef, useState } from 'react';

import { useGetSTT } from './useSTT';
import { toast } from 'sonner';

export default function useAudioRecorder() {
    const MIN_DECIBELS = -45;
    const VISUALIZER_BUFFER_LENGTH = 300;

    const [initialLoad, setInitialLoad] = useState(false);
    const [mediaRecorder, setMediaRecorder] = useState<MediaRecorder | null>(null);
    const [recording, setRecording] = useState(false);
    const chunks = useRef<Blob[]>([]);
    const hasSoundRef = useRef<boolean>(false);
    const saveAudio = useRef<boolean>(true)
    const [analyser, setAnalyser] = useState<AnalyserNode | null>(null)
    const [durationCounter, setDurationCounter] = useState<NodeJS.Timeout | null>(null)
    const [durationSeconds, setDurationSeconds] = useState(0);
    const [visualizerData, setVisualizerData] = useState(Array(VISUALIZER_BUFFER_LENGTH).fill(0))
    const [isDeviceFound, setIsDeviceFound] = useState(false);
    // Add a ref to store the animation frame ID for proper cleanup
    const animationFrameRef = useRef<number | null>(null);

    const sttMutation = useGetSTT()

    // Function to calculate the RMS level from time domain data
    const calculateRMS = (data: Uint8Array) => {
        let sumSquares = 0;
        for (let i = 0; i < data.length; i++) {
            const normalizedValue = (data[i] - 128) / 128; // Normalize the data
            sumSquares += normalizedValue * normalizedValue;
        }
        return Math.sqrt(sumSquares / data.length);
    };

    const normalizeRMS = (rms: number) => {
        rms = rms * 10;
        const exp = 1.5; // Adjust exponent value; values greater than 1 expand larger numbers more and compress smaller numbers more
        const scaledRMS = Math.pow(rms, exp);

        // Scale between 0.01 (1%) and 1.0 (100%)
        return Math.min(1.0, Math.max(0.01, scaledRMS));
    };

    const analyseAudio = useCallback(() => {
        if (!analyser) return;
        const bufferLength = analyser.frequencyBinCount;
        const domainData = new Uint8Array(bufferLength);
        const timeDomainData = new Uint8Array(analyser.fftSize);
        let lastSoundTime = Date.now();
        let hasStartedSpeaking = false
        
        // Clear any existing animation frame before starting a new one
        if (animationFrameRef.current !== null) {
            cancelAnimationFrame(animationFrameRef.current);
            animationFrameRef.current = null;
        }
        
        const detectSound = () => {
            const processFrame = () => {
                if (!recording) {
                    // Cancel animation frame if no longer recording
                    animationFrameRef.current = null;
                    return;
                }
                
                analyser.getByteTimeDomainData(timeDomainData);
                analyser.getByteFrequencyData(domainData);

                // Calculate RMS level from time domain data
                const rmsLevel = calculateRMS(timeDomainData);
                // Push the calculated decibel level to visualizerData
                setVisualizerData((prev) => {
                    if (prev.length >= VISUALIZER_BUFFER_LENGTH) {
                        prev.shift();
                    }
                    return [...prev, normalizeRMS(rmsLevel)];
                })

                // Check if initial speech/noise has started
                const hasSound = domainData.some((value) => value > 0);
                if (hasSound) {
                    hasSoundRef.current = true;
                    if (!hasStartedSpeaking) {
                        hasStartedSpeaking = true
                    }

                    lastSoundTime = Date.now();
                }

                // Start silence detection only after initial speech/noise has been detected
                if (hasStartedSpeaking) {
                    if (Date.now() - lastSoundTime > 2000) {
                        if (mediaRecorder) {
                            console.log('stop')
                            mediaRecorder.stop();
                            return;
                        }
                    }
                }

                // Store the animation frame ID for cleanup
                animationFrameRef.current = window.requestAnimationFrame(processFrame);
            };

            // Start the animation frame and store the ID
            animationFrameRef.current = window.requestAnimationFrame(processFrame);
        };

        detectSound();
        
        // Return cleanup function that cancels any active animation frame
        return () => {
            if (animationFrameRef.current !== null) {
                cancelAnimationFrame(animationFrameRef.current);
                animationFrameRef.current = null;
            }
        };
    }, [analyser, mediaRecorder, recording]);

    const initiateMediaRecoder = useCallback(
        (stream: MediaStream) => {
            const blobToFile = (blob: Blob, fileName: string) => {
                // Create a new File object from the Blob
                const file = new File([blob], fileName, { type: blob.type });
                return file;
            };

            const transcribe = async (file: File) => {
                const form = new FormData()
                form.append("file", file)
                form.append("language", "english")
                form.append("use_denoise", "true")
                sttMutation.mutate({ data: form })
            }

            const wavRecorder = new MediaRecorder(stream);

            // Event handler when recording starts
            wavRecorder.onstart = () => {
                chunks.current = []; // Resetting chunks array
            };

            // Event handler when data becomes available during recording
            wavRecorder.ondataavailable = (ev: BlobEvent) => {
                chunks.current.push(ev.data); // Storing data chunks
            };

            // Event handler when recording stops
            wavRecorder.onstop = () => {
                if (saveAudio.current) {
                    const mimeType = wavRecorder.mimeType;
                    const audioBlob = new Blob(chunks.current, { type: mimeType });
                    if (chunks.current.length > 0) {
                        const file = blobToFile(audioBlob, 'recording.wav');
                        transcribe(file);
                    }
                }
                saveAudio.current = true
                setRecording(false);
            };

            setMediaRecorder(wavRecorder);

            // Analyzer to activate only on certain noise level
            const audioCtx = new AudioContext();
            const sourceAnalyser = audioCtx.createAnalyser();
            const source = audioCtx.createMediaStreamSource(stream);
            source.connect(sourceAnalyser);
            sourceAnalyser.minDecibels = MIN_DECIBELS
            setAnalyser(sourceAnalyser)

            setIsDeviceFound(true);
        },
        [MIN_DECIBELS, sttMutation]
    );

    const startRecording = useCallback(() => {
        hasSoundRef.current = false;
        const startDurationCounter = () => {
            setDurationCounter(setInterval(() => {
                setDurationSeconds(prev => prev + 1);
            }, 1000));
        };

        try {
            if (mediaRecorder) {
                mediaRecorder.start();
                startDurationCounter();
                setRecording(true);
            }
        } catch (error) {
            setIsDeviceFound(false);
            if (error instanceof Error && error.name === 'NotSupportedError') {
                toast.error("Microphone device not found. Please refresh the page and allow microphone access.");
            } else {
                toast.error("Error recording audio. Please refresh the page and allow microphone access.");
            }
        }

        setVisualizerData(Array(VISUALIZER_BUFFER_LENGTH).fill(0))
    }, [mediaRecorder])

    const stopRecording = useCallback((save: boolean = true) => {
        saveAudio.current = save;
        const stopDurationCounter = () => {
            if (durationCounter !== null) {
                clearInterval(durationCounter);
            }
            setDurationSeconds(0);
        };

        if (mediaRecorder) {
            if (!hasSoundRef.current) {
                saveAudio.current = false;
                toast.error("No audio detected. Please try again.");
            }
            stopDurationCounter();
            mediaRecorder.stop();
        }
    }, [durationCounter, mediaRecorder]);

    const pauseRecording = useCallback(() => {
        if (mediaRecorder) {
            mediaRecorder.pause();
        }
    }, [mediaRecorder])

    const resumeRecording = useCallback(() => {
        if (mediaRecorder) {
            mediaRecorder.resume();
        }
    }, [mediaRecorder])


    useEffect(() => {
        async function loadRecorder(): Promise<void> {

            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            navigator.mediaDevices.ondevicechange = () => {
                setIsDeviceFound(false);
                toast.error("Microphone device not found. Please refresh the page and allow microphone access.");
            }
            initiateMediaRecoder(stream);
        }

        if (typeof window !== 'undefined' && !mediaRecorder && !initialLoad) {
            setInitialLoad(true);
            loadRecorder()
        }
    }, [mediaRecorder, initialLoad, initiateMediaRecoder]);

    useEffect(() => {
        if (recording) {
            const cleanup = analyseAudio();
            return cleanup;
        }
    }, [analyseAudio, recording])

    // Add cleanup to stop animation frames when recording stops
    useEffect(() => {
        if (!recording && animationFrameRef.current !== null) {
            cancelAnimationFrame(animationFrameRef.current);
            animationFrameRef.current = null;
        }
    }, [recording]);

    // Make sure to clean up animation frames when component unmounts
    useEffect(() => {
        return () => {
            if (animationFrameRef.current !== null) {
                cancelAnimationFrame(animationFrameRef.current);
                animationFrameRef.current = null;
            }
            // Clear any active timers
            if (durationCounter !== null) {
                clearInterval(durationCounter);
            }
        };
    }, []);

    return {
        startRecording,
        stopRecording,
        visualizerData,
        recording,
        durationSeconds,
        sttMutation,
        pauseRecording,
        resumeRecording,
        isDeviceFound
    };
};

export const preferredRegion = 'home'