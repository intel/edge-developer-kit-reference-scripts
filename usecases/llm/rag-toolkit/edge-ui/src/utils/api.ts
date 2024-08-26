// Copyright (C) 2024 Intel Corporation
// SPDX-License-Identifier: Apache-2.0

import { type APIResponse } from '@/types/api';

interface RequestConfig {
  headers?: Record<string, any>;
  data?: any;
  tags?: string[];
  revalidate?: number;
}

type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
const apiVersion = process.env.NEXT_PUBLIC_API_VERSION ?? "v1";

class FetchAPI {
  private baseURL: string;

  constructor(baseURL: string) {
    this.baseURL = new URL(`${apiVersion}/path`, baseURL).toString(); //This is to handle if apiVersion is null
  }

  private async request(method: HttpMethod, url: string, config: RequestConfig = {}): Promise<Response> {
    try {
      const { data, tags, revalidate, headers } = config;
      const fullURL = new URL(url, this.baseURL).toString();
      const options: RequestInit = {
        method,
        headers: headers ?? { 'Content-Type': 'application/json' },
        next: {
          ...(tags && { tags }),
          ...((revalidate || revalidate === 0) && { revalidate }),
        },
      };

      const request = new Request(fullURL, options);
      if (data && request.headers.get('Content-Type') === 'application/json') {
        options.body = JSON.stringify(data);
      } else {
        options.body = data;
      }
      const response = await fetch(fullURL, options);
      return response
    } catch (err) {
      console.log(err);
      return Response.error()
    }
  }

  private async handleResponse(response: Response): Promise<APIResponse> {
    const responseURL = response.url;
    const data = await response.json();
    if (!response.ok) {
      return {
        status: false,
        message: 'Error communicating with backend',
        url: response.url,
      } as APIResponse;
    }
    if (typeof data === 'object' && data !== null && 'status' in data)
      return data as APIResponse
    return { status: true, data, url: responseURL } as APIResponse;
  }

  public async get(url: string, config?: RequestConfig): Promise<APIResponse> {
    const response = await this.request('GET', url, config);
    return this.handleResponse(response)
  }

  public async post(url: string, data?: Record<string, any>, config?: RequestConfig): Promise<APIResponse> {
    const response = await this.request('POST', url, { ...config, data });
    return this.handleResponse(response)
  }

  public async put(url: string, data?: Record<string, any>, config?: RequestConfig): Promise<APIResponse> {
    const response = await this.request('PUT', url, { ...config, data });
    return this.handleResponse(response)
  }

  public async patch(url: string, data?: Record<string, any>, config?: RequestConfig): Promise<APIResponse> {
    const response = await this.request('PATCH', url, { ...config, data });
    return this.handleResponse(response)
  }

  public async delete(url: string, config?: RequestConfig): Promise<APIResponse> {
    const response = await this.request('DELETE', url, config);
    return this.handleResponse(response)
  }

  public async file(url: string, data?: Record<string, any>, config?: RequestConfig): Promise<Blob> {
    const response = await this.request('POST', url, { ...config, data });
    return await response.blob()
  }
}

export const API = new FetchAPI(`http://${process.env.NEXT_PUBLIC_API_URL ?? "localhost"}:${process.env.NEXT_PUBLIC_API_PORT ?? "8011"}`);
