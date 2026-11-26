#!/bin/sh
# Sfondo scuro (meno affaticamento / consumo) se xsetroot e' disponibile
command -v xsetroot >/dev/null 2>&1 && xsetroot -solid "#26313a"
