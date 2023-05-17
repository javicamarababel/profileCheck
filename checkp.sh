#!/bin/bash
function usage {
  echo "Uso: checkp.sh -d <dir wM> ( -f <fichero bundles.info> | -p <nombre profile> )"
  echo "-d <dir wM> es obligatorio solo si se pone -p"
  echo "Si se pone -d <dir wM> se comprobara que los jar existen y que no existe otra version superior"
  echo "Aparte de esta utilidad, puede ser util ejecutar la Diagnostic Tool con:"
  echo "cd $WM/common/lib/diagnostic-tool ; $WM/jvm/jvm/bin/java -jar diagnostic-collector.jar -default"
  echo "Eso deja el informe en ese mismo directorio"
}

function logErr {
  local msg=$1
  >&2 echo "checkp: ERROR: $msg"
}

function log {
  local msg=$1
  echo "checkp: $msg"
}

dirwM=""
ficheroBundlesInfo=""
nombreProfile=""
while [[ "$1" =~ ^- ]]; do
  if [ "$1" == "-d" ]; then
    shift
    dirwM=$1
  elif [ "$1" == "-f" ]; then
    shift
    ficheroBundlesInfo=$1
  elif [ "$1" == "-p" ]; then
    shift
    nombreProfile=$1
  else
    usage
    exit 1
  fi
  shift
done

if [ -z "$ficheroBundlesInfo" -a -z "$nombreProfile" ]; then
  usage
  exit 1
fi
if [ ! -z "$ficheroBundlesInfo" -a ! -z "$nombreProfile" ]; then
  usage
  exit 1
fi
if [ -z "$dirwM" -a ! -z "$nombreProfile" ]; then
  usage
  exit 1
fi

if [ ! -z "$dirwM" -a ! -d "$dirwM" ]; then
  logErr "El directorio $dirwM no existe" 
  exit 1
fi
if [ ! -z "$nombreProfile" ]; then
  dirProfile="$dirwM/profiles/$nombreProfile"
  if [ ! -d "$dirProfile" ]; then
    logErr "El directorio del profile $dirProfile no existe"
    exit 1
  fi
  ficheroBundlesInfo="$dirProfile/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info"
fi
if [ ! -r "$ficheroBundlesInfo" ]; then
  logErr "No puedo leer el fichero de bundles.info $ficheroBundlesInfo"
  exit 1
fi

log "--Revision de $ficheroBundlesInfo :"

# Bundles duplicados
tmpbundlesdup=`mktemp /tmp/tmpbundlesdupXXXXXX.lst`
grep -v "^#" "$ficheroBundlesInfo" | cut -d ',' -f 1 |sort|uniq -c $tmpbundles | grep -v "^      1 " > $tmpbundlesdup
rc=$?
if [ $rc -eq 0 ]; then
  log "Bundles duplicados:"
  cut -c 9- $tmpbundlesdup|while IFS= read -r bundle ; do 
    log "Bundle duplicado $bundle:"
    grep "^${bundle}," "$ficheroBundlesInfo"
  done
else
  log "No hay bundles duplicados"
fi
rm $tmpbundlesdup

# Bundles que no existen
if [ ! -z "$dirwM" ]; then
  bundlenoex=false
  grep -v "^#" "$ficheroBundlesInfo" | while IFS= read -r bundleLine ; do
    if [[ "$bundleLine" =~ ^([^,]+),([^,]+),([^,]+) ]]; then
      name=${BASH_REMATCH[1]}
      version=${BASH_REMATCH[2]}
      jarfile=${BASH_REMATCH[3]}
      if [[ "$jarfile" =~ ^\.\./\.\./(.*)$ ]]; then
        jarfile="$dirwM/${BASH_REMATCH[1]}"
      fi
      if [ ! -f "$jarfile" ]; then
        if [ $bundlenoex == false ]; then
          log "Bundles que no existen:"
          bundlenoex=true
        fi
        log "El fichero jar $jarfile no existe (bundle $name, version $version)"
      fi
    fi
  done
  if [ $bundlenoex == false ]; then
    log "No hay bundles que no existan"
  fi

  # Bundles con version superior disponible
  bundlesvsupfile=`mktemp /tmp/bundlesvsupXXXXX`
  if [ -f "$bundlesvsupfile" ]; then
    rm "$bundlesvsupfile"
  fi
  grep -v "^#" "$ficheroBundlesInfo" | while IFS= read -r bundleLine ; do
    if [[ "$bundleLine" =~ ^([^,]+),([^,]+),([^,]+) ]]; then
      name=${BASH_REMATCH[1]}
      version=${BASH_REMATCH[2]}
      jarfile=${BASH_REMATCH[3]}
      if [[ "$jarfile" =~ ^\.\./\.\./(.*)$ ]]; then
        jarfile="$dirwM/${BASH_REMATCH[1]}"
      fi
      if [[ "$jarfile" =~ ^(.+)_${version}.*$ ]]; then
        jarfilepr=${BASH_REMATCH[1]}
        ultjarfile=`ls -1 ${jarfilepr}_*.jar |tail -1`
        if [ "$ultjarfile" != "$jarfile" ]; then
          if [ ! -f $bundlesvsupfile ]; then
            log "Bundles de los que parece existir una version superior:"
  	    touch $bundlesvsupfile
          fi
          vsup=""
          if [[ "$ultjarfile" =~ ${name}_(.+).jar$ ]]; then
            vsup=${BASH_REMATCH[1]}
          fi
          log "Del bundle $name se usa la version $version , pero parece existir otra mayor $vsup:"
  	  echo $bundleLine
          echo "$ultjarfile"
        fi
      fi
    fi
  done
  if [ ! -f $bundlesvsupfile ]; then
    log "No veo bundles para los que parezca existir una version superior"
  else
    rm $bundlesvsupfile
  fi
fi
