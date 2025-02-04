// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { useContext } from 'react';

import { VideoQueueContext, VideoQueueContextProps } from '@/context/VideoQueueContext';


const useVideoQueue: () => VideoQueueContextProps = () => useContext(VideoQueueContext);

export default useVideoQueue;