import * as React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import { AppShell } from "../components/app-shell";

vi.stubGlobal("React", React);

describe("Production Control sidebar navigation", () => {
  it("places UV between Underprint and Dispatch without changing existing links", () => {
    const html = renderToStaticMarkup(React.createElement(AppShell, { children: null }));
    const execution = html.match(/<section><b>EXECUTION<\/b>(.*?)<\/section>/)?.[1];
    expect(execution).toBeDefined();

    const links = [...(execution ?? "").matchAll(/<a\b[^>]*href="([^"]+)"[^>]*>.*?<span>([^<]+)<\/span><\/a>/g)]
      .map(([, href, label]) => ({ label, href }));

    expect(links).toEqual([
      { label: "DTG", href: "/production/dtg" },
      { label: "Underprint", href: "/production/up" },
      { label: "UV", href: "/production/uv" },
      { label: "Dispatch", href: "/production/ready-to-lift" },
      { label: "Hold", href: "/production/hold-orders" },
      { label: "Scan", href: "/scan" },
    ]);
  });
});
