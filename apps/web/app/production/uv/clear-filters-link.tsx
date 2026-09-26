"use client";

import Link from "next/link";

export default function ClearFiltersLink() {
  return <Link href="/production/uv" onClick={event => {
    const form = event.currentTarget.closest("form");
    if (!form) return;
    const search = form.elements.namedItem("q");
    const stage = form.elements.namedItem("stage");
    if (search && "value" in search) search.value = "";
    if (stage && "value" in stage) stage.value = "ALL";
  }}>Clear</Link>;
}
