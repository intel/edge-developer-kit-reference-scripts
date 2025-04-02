// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

"use client"

import { useCallback, useEffect, useRef, useState } from 'react';

import { useGetSTT } from './useSTT';

export default function useAudioRecorder() {
    const MIN_DECIBELS = -45;
    const VISUALIZER_BUFFER_LENGTH = 300;

    const [initialLoad, setInitialLoad] = useState(false);
    const [mediaRecorder, setMediaRecorder] = useState<MediaRecorder | null>(null);
    const [recording, setRecording] = useState(false);
    const chunks = useRef<Blob[]>([]);
    const saveAudio = useRef<boolean>(true)
    const [analyser, setAnalyser] = useState<AnalyserNode | null>(null)
    const [durationCounter, setDurationCounter] = useState<NodeJS.Timeout | null>(null)
    const [durationSeconds, setDurationSeconds] = useState(0);
    const [visualizerData, setVisualizerData] = useState(Array(VISUALIZER_BUFFER_LENGTH).fill(0))

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

        const detectSound = () => {
            const processFrame = () => {
                if (recording) {
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

                    window.requestAnimationFrame(processFrame);
                }
            };

            window.requestAnimationFrame(processFrame);
        };

        detectSound();
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
        },
        [MIN_DECIBELS, sttMutation]
    );

    const startRecording = useCallback(() => {
        const startDurationCounter = () => {
            setDurationCounter(setInterval(() => {
                setDurationSeconds(prev => prev + 1);
            }, 1000));
        };

        if (mediaRecorder) {
            startDurationCounter();
            setRecording(true);
            mediaRecorder.start();
        }

        setVisualizerData(Array(VISUALIZER_BUFFER_LENGTH).fill(0))
    }, [mediaRecorder])

    const stopRecording = useCallback((save: boolean = true) => {
        saveAudio.current = save
        const stopDurationCounter = () => {
            if (durationCounter !== null) {
                clearInterval(durationCounter);
            }
            setDurationSeconds(0);
        };


        if (mediaRecorder) {
            stopDurationCounter()
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
            initiateMediaRecoder(stream);
        }

        if (typeof window !== 'undefined' && !mediaRecorder && !initialLoad) {
            setInitialLoad(true);
            void loadRecorder()
        }
    }, [mediaRecorder, initialLoad, initiateMediaRecoder]);

    useEffect(() => {
        if (recording) {
            analyseAudio()
        }
    }, [analyseAudio, recording])

    return {
        startRecording,
        stopRecording,
        visualizerData,
        recording,
        durationSeconds,
        sttMutation,
        pauseRecording,
        resumeRecording
    };
};

export const preferredRegion = 'home'