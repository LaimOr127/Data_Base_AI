#!/bin/bash
# Запуск полной переустановки с автоматическим подтверждением
cd "$(dirname "$0")"
AUTO_CONFIRM=yes ./full-reinstall-server.sh
