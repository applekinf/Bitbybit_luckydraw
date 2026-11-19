#!/bin/bash
# Mo bai hoc "Chuyen tau xuyen Viet" tren Mac
cd "$(dirname "$0")" || exit 1
clear
echo "Dang mo bai hoc..."
if /usr/bin/env python3 -c "import sys; sys.exit(0 if sys.version_info >= (3,7) else 1)" >/dev/null 2>&1; then
  /usr/bin/env python3 server.py
else
  echo ""
  echo "May chua co Python 3."
  echo "Neu Mac hien hop thoai 'Cai dat Command Line Tools', hay bam Cai dat (Install), doi xong roi mo lai file nay."
  echo "Hoac tai Python tai: https://www.python.org/downloads/macos/"
  open "https://www.python.org/downloads/macos/"
  read -r -p "Nhan Enter de dong cua so..."
fi
