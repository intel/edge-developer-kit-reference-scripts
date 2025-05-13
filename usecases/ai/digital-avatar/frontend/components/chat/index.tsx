// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import Chatbox from './Chatbox'

export default function Chat() {
    return (
        <>
            <div className="p-4 flex justify-between items-center border-b">
                <h2 className="text-xl font-semibold">Chat</h2>
            </div>
            <Chatbox />
        </>
    )
}