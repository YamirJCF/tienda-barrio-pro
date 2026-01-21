import { ref } from 'vue';

export function useNumpad(config: { onReset?: () => void } = {}) {
    const input = ref('');

    /**
     * Appends value to input or handles backspace/clear logic
     * @param value - The char to append or 'backspace'
     * @param modeActive - Whether any special mode (QTY/PROD) is active
     */
    const handleNumpad = (value: string, modeActive: boolean = false) => {
        if (value === 'backspace') {
            if (input.value.length > 0) {
                input.value = input.value.slice(0, -1);
            } else if (modeActive) {
                // Reset modes if backspace pressed on empty input while in a mode
                config.onReset?.();
            }
        } else {
            input.value += value;
        }
    };

    const clear = () => {
        input.value = '';
    };

    return {
        input,
        handleNumpad,
        clear,
    };
}
