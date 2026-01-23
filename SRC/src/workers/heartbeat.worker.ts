/// <reference lib="webworker" />

// Simple Worker to handle tick interval separate from main thread
// This avoids aggressive throttling by browsers when tab is backgrounded

const INTERVAL_MS = 60000; // 60s
let timerId: number | null = null;

self.onmessage = (e: MessageEvent) => {
    const { cmd } = e.data;

    if (cmd === 'start') {
        if (!timerId) {
            // Initial tick
            self.postMessage({ type: 'tick' });

            timerId = self.setInterval(() => {
                self.postMessage({ type: 'tick' });
            }, INTERVAL_MS);
        }
    } else if (cmd === 'stop') {
        if (timerId) {
            self.clearInterval(timerId);
            timerId = null;
        }
    }
};
