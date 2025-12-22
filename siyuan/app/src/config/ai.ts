import {fetchPost} from "../util/fetch";

export const ai = {
    element: undefined as Element,
    genHTML: () => {
        // Определяем активный провайдер (приоритет: Ollama > Gemini > OpenAI)
        const ollamaConfig = window.siyuan.config.ai.ollama || {};
        const geminiConfig = window.siyuan.config.ai.gemini || {};
        const openAIConfig = window.siyuan.config.ai.openAI || {};
        const isOllama = ollamaConfig.apiBaseURL && ollamaConfig.apiBaseURL !== "";
        const isGemini = geminiConfig && geminiConfig.apiKey;
        const currentProvider = isOllama ? "Ollama" : (isGemini ? "Gemini" : (openAIConfig.apiProvider || "OpenAI"));
        
        let responsiveHTML = "";
        /// #if MOBILE
        responsiveHTML = `<div class="b3-label">
    ${window.siyuan.languages.apiProvider}
    <div class="b3-label__text">
        ${window.siyuan.languages.apiProviderTip}
    </div>
    <div class="b3-label__text fn__flex config__item">
        <select id="apiProvider" class="b3-select">
            <option value="Ollama" ${currentProvider === "Ollama" ? "selected" : ""}>Ollama</option>
            <option value="Gemini" ${currentProvider === "Gemini" ? "selected" : ""}>Gemini</option>
            <option value="OpenAI" ${currentProvider === "OpenAI" ? "selected" : ""}>OpenAI</option>
            <option value="Azure" ${currentProvider === "Azure" ? "selected" : ""}>Azure</option>
        </select>
    </div>
</div>
<div class="b3-label">
    ${window.siyuan.languages.apiTimeout}
    <div class="fn__hr"></div>
    <div class="fn__flex">
        <input class="b3-text-field fn__flex-1" type="number" step="1" min="5" max="600" id="apiTimeout" value="${isOllama ? (ollamaConfig.apiTimeout || 30) : (isGemini ? (geminiConfig.apiTimeout || 30) : (openAIConfig.apiTimeout || 30))}"/>
        <span class="fn__space"></span>
        <span class="ft__on-surface fn__flex-center">s</span>
    </div>
    <div class="b3-label__text">${window.siyuan.languages.apiTimeoutTip}</div>
</div>
<div class="b3-label">
    ${window.siyuan.languages.apiMaxTokens}
    <div class="fn__hr"></div>
        <input class="b3-text-field fn__flex-center fn__block" type="number" step="1" min="0" id="apiMaxTokens" value="${isOllama ? (ollamaConfig.apiMaxTokens || 0) : (isGemini ? (geminiConfig.apiMaxTokens || 0) : (openAIConfig.apiMaxTokens || 0))}" ${isOllama ? 'data-ollama="true"' : ''}/>
    <div class="b3-label__text">${window.siyuan.languages.apiMaxTokensTip}</div>
</div>
<div class="b3-label">
    ${window.siyuan.languages.apiTemperature}
    <div class="fn__hr"></div>
        <input class="b3-text-field fn__flex-center fn__block" type="number" step="0.1" min="0" max="2" id="apiTemperature" value="${isOllama ? (ollamaConfig.apiTemperature || 1.0) : (isGemini ? (geminiConfig.apiTemperature || 1.0) : (openAIConfig.apiTemperature || 1.0))}"/>
    <div class="b3-label__text">${window.siyuan.languages.apiTemperatureTip}</div>
</div>
<div class="b3-label">
    ${window.siyuan.languages.apiMaxContexts}
    <div class="fn__hr"></div>
        <input class="b3-text-field fn__flex-center fn__block" type="number" step="1" min="1" max="64" id="apiMaxContexts" value="${isOllama ? (ollamaConfig.apiMaxContexts || 7) : (isGemini ? (geminiConfig.apiMaxContexts || 7) : (openAIConfig.apiMaxContexts || 7))}"/>
    <div class="b3-label__text">${window.siyuan.languages.apiMaxContextsTip}</div>
</div>
<div class="b3-label">
    ${window.siyuan.languages.apiModel}
    <div class="fn__hr"></div>
    <input class="b3-text-field fn__block" id="apiModel" value="${isOllama ? (ollamaConfig.apiModel || "nemotron-3-nano:30b-cloud") : (isGemini ? (geminiConfig.apiModel || "gemini-1.5-flash") : (openAIConfig.apiModel || "gpt-3.5-turbo"))}"/>
    <div class="b3-label__text">${window.siyuan.languages.apiModelTip}</div>
</div>
<div class="b3-label">
    ${window.siyuan.languages.apiKey}
    <div class="fn__hr"></div>
    <div class="b3-form__icona fn__block">
        <input id="apiKey" type="password" class="b3-text-field b3-form__icona-input" value="${window.siyuan.config.ai.openAI.apiKey}">
        <svg class="b3-form__icona-icon" data-action="togglePassword"><use xlink:href="#iconEye"></use></svg>
    </div>
    <div class="b3-label__text">${window.siyuan.languages.apiKeyTip}</div>
</div>
<div class="b3-label">
    ${window.siyuan.languages.apiProxy}
    <div class="fn__hr"></div>
    <input class="b3-text-field fn__block" id="apiProxy" value="${isOllama ? (ollamaConfig.apiProxy || "") : (isGemini ? (geminiConfig.apiProxy || "") : (openAIConfig.apiProxy || ""))}"/>
    <div class="b3-label__text">${window.siyuan.languages.apiProxyTip}</div>
</div>
<div class="b3-label">
    ${window.siyuan.languages.apiBaseURL}
    <div class="fn__hr"></div>
    <input class="b3-text-field fn__block" id="apiBaseURL" value="${isOllama ? (ollamaConfig.apiBaseURL || "http://localhost:11434") : (isGemini ? (geminiConfig.apiBaseURL || "https://generativelanguage.googleapis.com/v1beta") : (openAIConfig.apiBaseURL || "https://api.openai.com/v1"))}"/>
    <div class="b3-label__text">${window.siyuan.languages.apiBaseURLTip}</div>
</div>
<div class="b3-label">
    ${window.siyuan.languages.apiVersion}
    <div class="fn__hr"></div>
    <input class="b3-text-field fn__block" id="apiVersion" value="${window.siyuan.config.ai.openAI.apiVersion}"/>
    <div class="b3-label__text">${window.siyuan.languages.apiVersionTip}</div>
</div>
<div class="b3-label">
    User-Agent
    <div class="fn__hr"></div>
    <input class="b3-text-field fn__block" id="apiUserAgent" value="${window.siyuan.config.ai.openAI.apiUserAgent}"/>
    <div class="b3-label__text">${window.siyuan.languages.apiUserAgentTip}</div>
</div>`;
        /// #else
        responsiveHTML = `<div class="fn__flex b3-label config__item">
    <div class="fn__flex-1">
        ${window.siyuan.languages.apiProvider}
        <div class="b3-label__text">${window.siyuan.languages.apiProviderTip}</div>
    </div>
    <span class="fn__space"></span>
    <select id="apiProvider" class="b3-select fn__flex-center fn__size200">
        <option value="Ollama" ${currentProvider === "Ollama" ? "selected" : ""}>Ollama</option>
        <option value="Gemini" ${currentProvider === "Gemini" ? "selected" : ""}>Gemini</option>
        <option value="OpenAI" ${currentProvider === "OpenAI" ? "selected" : ""}>OpenAI</option>
        <option value="Azure" ${currentProvider === "Azure" ? "selected" : ""}>Azure</option>
    </select>
</div>
<div class="fn__flex b3-label">
    <div class="fn__flex-1">
        ${window.siyuan.languages.apiTimeout}
        <div class="b3-label__text">${window.siyuan.languages.apiTimeoutTip}</div>
    </div>
    <span class="fn__space"></span>
    <div class="fn__size200 fn__flex-center fn__flex">
        <input class="b3-text-field fn__flex-1" type="number" step="1" min="5" max="600" id="apiTimeout" value="${isOllama ? (ollamaConfig.apiTimeout || 30) : (isGemini ? (geminiConfig.apiTimeout || 30) : (openAIConfig.apiTimeout || 30))}"/>
        <span class="fn__space"></span>
        <span class="ft__on-surface fn__flex-center">s</span>
    </div>
</div>
<div class="fn__flex b3-label">
    <div class="fn__flex-1">
        ${window.siyuan.languages.apiMaxTokens}
        <div class="b3-label__text">${window.siyuan.languages.apiMaxTokensTip}</div>
    </div>
    <span class="fn__space"></span>
    <input class="b3-text-field fn__flex-center fn__size200" type="number" step="1" min="0" id="apiMaxTokens" value="${isOllama ? (ollamaConfig.apiMaxTokens || 0) : (isGemini ? (geminiConfig.apiMaxTokens || 0) : (openAIConfig.apiMaxTokens || 0))}"/>
</div>
<div class="fn__flex b3-label">
    <div class="fn__flex-1">
        ${window.siyuan.languages.apiTemperature}
        <div class="b3-label__text">${window.siyuan.languages.apiTemperatureTip}</div>
    </div>
    <span class="fn__space"></span>
        <input class="b3-text-field fn__flex-center fn__size200" type="number" step="0.1" min="0" max="2" id="apiTemperature" value="${isOllama ? (ollamaConfig.apiTemperature || 1.0) : (isGemini ? (geminiConfig.apiTemperature || 1.0) : (openAIConfig.apiTemperature || 1.0))}"/>
</div>
<div class="fn__flex b3-label">
    <div class="fn__flex-1">
        ${window.siyuan.languages.apiMaxContexts}
        <div class="b3-label__text">${window.siyuan.languages.apiMaxContextsTip}</div>
    </div>
    <span class="fn__space"></span>
        <input class="b3-text-field fn__flex-center fn__size200" type="number" step="1" min="1" max="64" id="apiMaxContexts" value="${isOllama ? (ollamaConfig.apiMaxContexts || 7) : (isGemini ? (geminiConfig.apiMaxContexts || 7) : (openAIConfig.apiMaxContexts || 7))}"/>
</div>
<div class="fn__flex b3-label">
    <div class="fn__block">
        ${window.siyuan.languages.apiModel}
        <div class="b3-label__text">${window.siyuan.languages.apiModelTip}</div>
        <div class="fn__hr"></div>
        <input class="b3-text-field fn__block" id="apiModel" value="${isOllama ? (ollamaConfig.apiModel || "nemotron-3-nano:30b-cloud") : (isGemini ? (geminiConfig.apiModel || "gemini-1.5-flash") : (openAIConfig.apiModel || "gpt-3.5-turbo"))}"/>
    </div>
</div>
<div class="fn__flex b3-label">
    <div class="fn__block">
        ${window.siyuan.languages.apiKey}
        <div class="b3-label__text">${window.siyuan.languages.apiKeyTip}</div>
        <div class="fn__hr"></div>
        <div class="b3-form__icona fn__block">
            <input id="apiKey" type="password" class="b3-text-field b3-form__icona-input" value="${isOllama ? "" : (isGemini ? (geminiConfig.apiKey || "") : (openAIConfig.apiKey || ""))}">
            <svg class="b3-form__icona-icon" data-action="togglePassword"><use xlink:href="#iconEye"></use></svg>
        </div>
    </div>
</div>
<div class="fn__flex b3-label">
    <div class="fn__block">
        ${window.siyuan.languages.apiProxy}
        <div class="b3-label__text">${window.siyuan.languages.apiProxyTip}</div>
        <span class="fn__hr"></span>
        <input class="b3-text-field fn__block" id="apiProxy" value="${isOllama ? (ollamaConfig.apiProxy || "") : (isGemini ? (geminiConfig.apiProxy || "") : (openAIConfig.apiProxy || ""))}"/>
    </div>
</div>
<div class="fn__flex b3-label">
    <div class="fn__block">
        ${window.siyuan.languages.apiBaseURL}
        <div class="b3-label__text">${window.siyuan.languages.apiBaseURLTip}</div>
        <span class="fn__hr"></span>
        <input class="b3-text-field fn__block" id="apiBaseURL" value="${isOllama ? (ollamaConfig.apiBaseURL || "http://localhost:11434") : (isGemini ? (geminiConfig.apiBaseURL || "https://generativelanguage.googleapis.com/v1beta") : (openAIConfig.apiBaseURL || "https://api.openai.com/v1"))}"/>
    </div>
</div>
<div class="fn__flex b3-label">
    <div class="fn__block">
        ${window.siyuan.languages.apiVersion}
        <div class="b3-label__text">${window.siyuan.languages.apiVersionTip}</div>
        <span class="fn__hr"></span>
        <input class="b3-text-field fn__block" id="apiVersion" value="${window.siyuan.config.ai.openAI.apiVersion}"/>
    </div>
</div>
<div class="fn__flex b3-label">
    <div class="fn__block">
        User-Agent
        <div class="b3-label__text">${window.siyuan.languages.apiUserAgentTip}</div>
        <span class="fn__hr"></span>
        <input class="b3-text-field fn__block" id="apiUserAgent" value="${window.siyuan.config.ai.openAI.apiUserAgent}"/>
    </div>
</div>`;
        /// #endif
        return `<div class="fn__flex-column" style="height: 100%">
<div class="layout-tab-bar fn__flex">
    <div data-type="openai" class="item item--full item--focus"><span class="fn__flex-1"></span><span class="item__text">OpenAI</span><span class="fn__flex-1"></span></div>
</div>
<div class="fn__flex-1">
    <div data-type="openai">
        ${responsiveHTML}
    </div>
</div>
</div>`;
    },
    bindEvent: () => {
        const togglePassword = ai.element.querySelector('.b3-form__icona-icon[data-action="togglePassword"]');
        if (togglePassword) {
            togglePassword.addEventListener("click", () => {
                const isEye = togglePassword.firstElementChild.getAttribute("xlink:href") === "#iconEye";
                togglePassword.firstElementChild.setAttribute("xlink:href", isEye ? "#iconEyeoff" : "#iconEye");
                togglePassword.previousElementSibling.setAttribute("type", isEye ? "text" : "password");
            });
        }
        
        // Обработчик изменения провайдера
        const providerSelect = ai.element.querySelector("#apiProvider") as HTMLSelectElement;
        
        // Скрываем ненужные поля при загрузке, если выбран Ollama
        if (providerSelect && providerSelect.value === "Ollama") {
            const versionField = ai.element.querySelector("#apiVersion")?.parentElement?.parentElement;
            const userAgentField = ai.element.querySelector("#apiUserAgent")?.parentElement?.parentElement;
            const apiKeyField = ai.element.querySelector("#apiKey")?.parentElement?.parentElement;
            if (versionField) versionField.classList.add("fn__none");
            if (userAgentField) userAgentField.classList.add("fn__none");
            if (apiKeyField) apiKeyField.classList.add("fn__none");
        }
        if (providerSelect) {
            providerSelect.addEventListener("change", () => {
                const provider = providerSelect.value;
                const geminiConfig = window.siyuan.config.ai.gemini || {};
                const openAIConfig = window.siyuan.config.ai.openAI || {};
                
                // Обновляем поля формы в зависимости от выбранного провайдера
                const ollamaConfig = window.siyuan.config.ai.ollama || {};
                if (provider === "Ollama") {
                    (ai.element.querySelector("#apiModel") as HTMLInputElement).value = ollamaConfig.apiModel || "nemotron-3-nano:30b-cloud";
                    (ai.element.querySelector("#apiKey") as HTMLInputElement).value = "";
                    (ai.element.querySelector("#apiBaseURL") as HTMLInputElement).value = ollamaConfig.apiBaseURL || "http://localhost:11434";
                    (ai.element.querySelector("#apiTimeout") as HTMLInputElement).value = (ollamaConfig.apiTimeout || 30).toString();
                    (ai.element.querySelector("#apiMaxTokens") as HTMLInputElement).value = (ollamaConfig.apiMaxTokens || 0).toString();
                    (ai.element.querySelector("#apiTemperature") as HTMLInputElement).value = (ollamaConfig.apiTemperature || 1.0).toString();
                    (ai.element.querySelector("#apiMaxContexts") as HTMLInputElement).value = (ollamaConfig.apiMaxContexts || 7).toString();
                    (ai.element.querySelector("#apiProxy") as HTMLInputElement).value = ollamaConfig.apiProxy || "";
                    // Скрываем поля, специфичные для OpenAI
                    const versionField = ai.element.querySelector("#apiVersion")?.parentElement?.parentElement;
                    const userAgentField = ai.element.querySelector("#apiUserAgent")?.parentElement?.parentElement;
                    const apiKeyField = ai.element.querySelector("#apiKey")?.parentElement?.parentElement;
                    if (versionField) versionField.classList.add("fn__none");
                    if (userAgentField) userAgentField.classList.add("fn__none");
                    if (apiKeyField) apiKeyField.classList.add("fn__none");
                } else if (provider === "Gemini") {
                    (ai.element.querySelector("#apiModel") as HTMLInputElement).value = geminiConfig.apiModel || "gemini-1.5-flash";
                    (ai.element.querySelector("#apiKey") as HTMLInputElement).value = geminiConfig.apiKey || "AIzaSyCby8forvtNvqZYBCJozW-VlI0GuUQrE4A";
                    (ai.element.querySelector("#apiBaseURL") as HTMLInputElement).value = geminiConfig.apiBaseURL || "https://generativelanguage.googleapis.com/v1beta";
                    (ai.element.querySelector("#apiTimeout") as HTMLInputElement).value = (geminiConfig.apiTimeout || 30).toString();
                    (ai.element.querySelector("#apiMaxTokens") as HTMLInputElement).value = (geminiConfig.apiMaxTokens || 0).toString();
                    (ai.element.querySelector("#apiTemperature") as HTMLInputElement).value = (geminiConfig.apiTemperature || 1.0).toString();
                    (ai.element.querySelector("#apiMaxContexts") as HTMLInputElement).value = (geminiConfig.apiMaxContexts || 7).toString();
                    (ai.element.querySelector("#apiProxy") as HTMLInputElement).value = geminiConfig.apiProxy || "";
                    // Скрываем поля, специфичные для OpenAI
                    const versionField = ai.element.querySelector("#apiVersion")?.parentElement?.parentElement;
                    const userAgentField = ai.element.querySelector("#apiUserAgent")?.parentElement?.parentElement;
                    const apiKeyField = ai.element.querySelector("#apiKey")?.parentElement?.parentElement;
                    if (versionField) versionField.classList.add("fn__none");
                    if (userAgentField) userAgentField.classList.add("fn__none");
                    if (apiKeyField) apiKeyField.classList.remove("fn__none");
                } else {
                    (ai.element.querySelector("#apiModel") as HTMLInputElement).value = openAIConfig.apiModel || "gpt-3.5-turbo";
                    (ai.element.querySelector("#apiKey") as HTMLInputElement).value = openAIConfig.apiKey || "";
                    (ai.element.querySelector("#apiBaseURL") as HTMLInputElement).value = openAIConfig.apiBaseURL || "https://api.openai.com/v1";
                    (ai.element.querySelector("#apiTimeout") as HTMLInputElement).value = (openAIConfig.apiTimeout || 30).toString();
                    (ai.element.querySelector("#apiMaxTokens") as HTMLInputElement).value = (openAIConfig.apiMaxTokens || 0).toString();
                    (ai.element.querySelector("#apiTemperature") as HTMLInputElement).value = (openAIConfig.apiTemperature || 1.0).toString();
                    (ai.element.querySelector("#apiMaxContexts") as HTMLInputElement).value = (openAIConfig.apiMaxContexts || 7).toString();
                    (ai.element.querySelector("#apiProxy") as HTMLInputElement).value = openAIConfig.apiProxy || "";
                    (ai.element.querySelector("#apiVersion") as HTMLInputElement).value = openAIConfig.apiVersion || "";
                    (ai.element.querySelector("#apiUserAgent") as HTMLInputElement).value = openAIConfig.apiUserAgent || "";
                    // Показываем поля, специфичные для OpenAI
                    const versionField = ai.element.querySelector("#apiVersion")?.parentElement?.parentElement;
                    const userAgentField = ai.element.querySelector("#apiUserAgent")?.parentElement?.parentElement;
                    const apiKeyField = ai.element.querySelector("#apiKey")?.parentElement?.parentElement;
                    if (versionField) versionField.classList.remove("fn__none");
                    if (userAgentField) userAgentField.classList.remove("fn__none");
                    if (apiKeyField) apiKeyField.classList.remove("fn__none");
                }
            });
        }
        
        ai.element.querySelectorAll("input, select").forEach((item) => {
            item.addEventListener("change", () => {
                const provider = (ai.element.querySelector("#apiProvider") as HTMLSelectElement).value;
                const apiData: any = {
                    openAI: {
                        apiUserAgent: (ai.element.querySelector("#apiUserAgent") as HTMLInputElement).value,
                        apiBaseURL: (ai.element.querySelector("#apiBaseURL") as HTMLInputElement).value,
                        apiVersion: (ai.element.querySelector("#apiVersion") as HTMLInputElement).value,
                        apiKey: (ai.element.querySelector("#apiKey") as HTMLInputElement).value,
                        apiModel: (ai.element.querySelector("#apiModel") as HTMLInputElement).value,
                        apiMaxTokens: parseInt((ai.element.querySelector("#apiMaxTokens") as HTMLInputElement).value) || 0,
                        apiTemperature: parseFloat((ai.element.querySelector("#apiTemperature") as HTMLInputElement).value) || 1.0,
                        apiMaxContexts: parseInt((ai.element.querySelector("#apiMaxContexts") as HTMLInputElement).value) || 7,
                        apiProxy: (ai.element.querySelector("#apiProxy") as HTMLInputElement).value,
                        apiTimeout: parseInt((ai.element.querySelector("#apiTimeout") as HTMLInputElement).value) || 30,
                        apiProvider: provider === "OpenAI" || provider === "Azure" ? provider : "OpenAI",
                    }
                };
                
                // Если выбран Ollama, добавляем настройки Ollama
                if (provider === "Ollama") {
                    apiData.ollama = {
                        apiModel: (ai.element.querySelector("#apiModel") as HTMLInputElement).value || "nemotron-3-nano:30b-cloud",
                        apiMaxTokens: parseInt((ai.element.querySelector("#apiMaxTokens") as HTMLInputElement).value) || 0,
                        apiTemperature: parseFloat((ai.element.querySelector("#apiTemperature") as HTMLInputElement).value) || 1.0,
                        apiMaxContexts: parseInt((ai.element.querySelector("#apiMaxContexts") as HTMLInputElement).value) || 7,
                        apiProxy: (ai.element.querySelector("#apiProxy") as HTMLInputElement).value,
                        apiTimeout: parseInt((ai.element.querySelector("#apiTimeout") as HTMLInputElement).value) || 30,
                        apiBaseURL: (ai.element.querySelector("#apiBaseURL") as HTMLInputElement).value || "http://localhost:11434",
                    };
                } else if (provider === "Gemini") {
                    // Если выбран Gemini, добавляем настройки Gemini
                    apiData.gemini = {
                        apiKey: (ai.element.querySelector("#apiKey") as HTMLInputElement).value,
                        apiModel: (ai.element.querySelector("#apiModel") as HTMLInputElement).value || "gemini-1.5-flash",
                        apiMaxTokens: parseInt((ai.element.querySelector("#apiMaxTokens") as HTMLInputElement).value) || 0,
                        apiTemperature: parseFloat((ai.element.querySelector("#apiTemperature") as HTMLInputElement).value) || 1.0,
                        apiMaxContexts: parseInt((ai.element.querySelector("#apiMaxContexts") as HTMLInputElement).value) || 7,
                        apiProxy: (ai.element.querySelector("#apiProxy") as HTMLInputElement).value,
                        apiTimeout: parseInt((ai.element.querySelector("#apiTimeout") as HTMLInputElement).value) || 30,
                        apiBaseURL: (ai.element.querySelector("#apiBaseURL") as HTMLInputElement).value || "https://generativelanguage.googleapis.com/v1beta",
                    };
                }
                
                fetchPost("/api/setting/setAI", apiData, response => {
                    window.siyuan.config.ai = response.data;
                });
            });
        });
    },
};
