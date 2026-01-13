#!/usr/bin/env python3
import json

conf_path = 'workspace/conf/conf.json'
with open(conf_path, 'r', encoding='utf-8') as f:
    conf = json.load(f)

# Инициализируем AI настройки
if 'ai' not in conf:
    conf['ai'] = {}

# Настройка ОБЕИХ секций для Ollama
conf['ai']['ollama'] = {
    'apiBaseURL': 'http://host.docker.internal:11434',
    'apiKey': '',
    'apiModel': 'nemotron-3-nano:30b-cloud',
    'apiMaxTokens': 4096,
    'apiTimeout': 60,
    'apiMaxContexts': 10,
    'apiTemperature': 1,
    'apiProxy': ''
}

conf['ai']['openAI'] = {
    'apiBaseURL': 'http://host.docker.internal:11434/v1',
    'apiKey': 'ollama',
    'apiModel': 'nemotron-3-nano:30b-cloud',
    'apiMaxTokens': 4096,
    'apiTimeout': 60,
    'apiMaxContexts': 10,
    'apiTemperature': 1,
    'apiProxy': '',
    'apiProvider': 'OpenAI',
    'apiVersion': '',
    'apiUserAgent': 'DIGroup/3.4.2 docker/linux'
}

# Сохраняем
with open(conf_path, 'w', encoding='utf-8') as f:
    json.dump(conf, f, ensure_ascii=False, indent=2)

print('✓ ИИ настроен на Ollama Cloud')
print('  Модель: nemotron-3-nano:30b-cloud')
print('  API: http://host.docker.internal:11434')
print('  Параметры: 30B, облачная, быстрая')
