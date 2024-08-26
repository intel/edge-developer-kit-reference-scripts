// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { Popover, Slider, Stack, Typography } from "@mui/material";
import React from "react";

export default function TemperaturePopover({ temperature, updateTemperature, open, anchorEl, handleClose }:
    {
        temperature: number, updateTemperature: (temp: number) => void,
        open: boolean, anchorEl: HTMLDivElement | null, handleClose: VoidFunction
    }): React.JSX.Element {

    const handleChange = (event: Event, newValue: number | number[]): void => {
        updateTemperature(newValue as number);
    };

    return (
        <Popover
            id="language-popover"
            open={open}
            anchorEl={anchorEl}
            onClose={handleClose}
            anchorOrigin={{
                vertical: 'top',
                horizontal: 'left',
            }}
            transformOrigin={{
                vertical: 'bottom',
                horizontal: 'left',
            }}
        >
            <Stack sx={{ p: "1rem", minWidth: "150px", gap: ".5rem" }}>
                <Typography variant="body2" fontWeight="bold">Temperature</Typography>
                <Slider step={0.01} min={0} max={1} valueLabelDisplay="auto" aria-label="temperature" value={temperature} onChange={handleChange} />
            </Stack>
        </Popover>
    )
}