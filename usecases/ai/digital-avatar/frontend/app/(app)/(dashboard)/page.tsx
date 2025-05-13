// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

'use client'

import Avatar from "@/components/avatar"
import Chat from "@/components/chat"

export default function Component() {

  return (
    <div className="mx-auto h-screen bg-gradient-to-b from-primary/20 to-background">
      <div className="h-full grid grid-cols-1 md:grid-cols-12">
        <div className="md:col-span-9 relative overflow-hidden">
          <Avatar />
        </div>
        <div className={`md:col-span-3 flex flex-col bg-background rounded-t-3xl md:rounded-none shadow-lg h-full transition-all duration-300 ease-in-out`}>
          <Chat />
        </div>
      </div>
    </div>
  )
}