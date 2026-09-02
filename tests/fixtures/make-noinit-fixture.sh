#!/bin/bash
# fresh-app after a session that added a Header component without ever running init (uncommitted)
set -e; base="$1"; src="$2"; a="$base/noinit-app"; rm -rf "$a"; cp -R "$src/fresh-app" "$a"; cd "$a"
printf 'export function Header() { return <header><h1>fresh-app</h1></header>; }\n' > src/Header.tsx
printf 'import { Header } from "./Header";\nexport function App() { return <><Header /><h1>fresh</h1></>; }\n' > src/App.tsx
echo "built noinit-app: branch=$(git branch --show-current) dirty=$(git status --short | tr '\n' ' ')"
