"use client";

import Link from "next/link";

const filterNames = ["q", "status", "customer", "priority", "due", "process", "blocker"] as const;

export default function ClearFiltersLink() {
  return <Link href="/production/release-queue" onClick={(event) => {
    const form = event.currentTarget.closest("form");
    if (!form) return;
    for (const name of filterNames) {
      const control = form.elements.namedItem(name);
      if (control && "value" in control) control.value = name === "status" ? "ALL" : "";
    }
  }}>Clear</Link>;
}
