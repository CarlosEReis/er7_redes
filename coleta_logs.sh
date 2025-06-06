#!/usr/bin/tclsh

# Script de Diagnóstico Automatizado para Cisco IOS
# Salve este arquivo como "diagnostico.tcl" no seu pendrive
# Execute com: source usbflash0:diagnostico.tcl

# Configurações iniciais
ios_config "terminal length 0" ""
ios_config "terminal file prompt quiet" ""

# Captura o hostname para nomear o arquivo
set hostname [exec "show running-config | include hostname"]
regexp {hostname\s+(\S+)} $hostname match nome_host
if {![info exists nome_host]} {
    set nome_host "switch"
}

# Captura o número de série do equipamento
proc obter_numero_serie {} {
# Método 1: Tenta show version primeiro (mais comum)
    if {[catch {exec "show version"} version_output]} {
        set serial_number "UNKNOWN"
    } else {
        # Procura por diferentes padrões de serial number
        if {[regexp -nocase {System Serial Number\s*:\s*(\S+)} $version_output match serial_number]} {
            # Padrão para switches Catalyst
            return $serial_number
        } elseif {[regexp -nocase {Processor board ID\s+(\S+)} $version_output match serial_number]} {
            # Padrão para roteadores
            return $serial_number
        } elseif {[regexp -nocase {Serial Number\s*:\s*(\S+)} $version_output match serial_number]} {
            # Padrão genérico
            return $serial_number
        }
    }
    
    # Método 2: Tenta show inventory se show version não funcionou
    if {[catch {exec "show inventory"} inventory_output]} {
        return "UNKNOWN"
    } else {
        # Procura pelo SN no inventory (primeira ocorrência - chassis principal)
        if {[regexp -nocase {SN:\s*(\S+)} $inventory_output match serial_number]} {
            return $serial_number
        }
    }
    
    # Método 3: Tenta show platform (para alguns modelos específicos)
    if {[catch {exec "show platform"} platform_output]} {
        return "UNKNOWN"
    } else {
        if {[regexp -nocase {Serial Number\s*:\s*(\S+)} $platform_output match serial_number]} {
            return $serial_number
        }
    }
    
    return "UNKNOWN"
}

# Captura o número de série do equipamento
set numero_serie [obter_numero_serie]

# Define o caminho do arquivo de saída no pendrive
set arquivo_saida "flash:logs_${nome_host}_${numero_serie}.txt"

# Lista de comandos para executar
set comandos {
    "show running-config"
    "show version"
    "show platform" 
    "show inventory"
    "show license usage"
    "show app-hosting list"
}

# Função para adicionar cabeçalho com timestamp
proc adicionar_cabecalho {arquivo comando} {
    set timestamp [clock format [clock seconds] -format "%d/%m/%Y %H:%M:%S"]
    set separador [string repeat "=" 80]
    puts $arquivo "\n$separador"
    puts $arquivo "COMANDO: $comando"
    puts $arquivo "DATA/HORA: $timestamp"
    puts $arquivo "$separador\n"
}

# Inicia o diagnóstico
puts "\n"
puts "Iniciando coleta de log automatizado..."
puts "Arquivo de saida $arquivo_saida"
puts ""

# Abre o arquivo para escrita
set arquivo [open $arquivo_saida w]

# Cabeçalho inicial do relatório
set timestamp_inicio [clock format [clock seconds] -format "%d/%m/%Y %H:%M:%S"]
puts $arquivo [string repeat "=" 80]
puts $arquivo "RELATORIO DE COLETA DE LOGS AUTOMATIZADO"
puts $arquivo "EQUIPAMENTO: $nome_host"
puts $arquivo "INICIO: $timestamp_inicio"
puts $arquivo [string repeat "=" 80]

# Executa cada comando da lista
foreach comando $comandos {
    puts "Coletando log de: $comando"
    
    # Adiciona cabeçalho
    adicionar_cabecalho $arquivo $comando
    
    # Executa o comando e captura a saída
    if {[catch {exec $comando} resultado]} {
        puts $arquivo "ERRO: Nao foi possivel executar o comando"
        puts $arquivo "Detalhes: $resultado"
    } else {
        puts $arquivo $resultado
    }
    
    # Adiciona espaçamento
    puts $arquivo "\n"
}

# Rodapé do relatório
set timestamp_fim [clock format [clock seconds] -format "%d/%m/%Y %H:%M:%S"]
puts $arquivo [string repeat "=" 80]
puts $arquivo "FIM DA COLETA DE LOGS"
puts $arquivo "TERMINO: $timestamp_fim"
puts $arquivo [string repeat "=" 80]

# Fecha o arquivo
close $arquivo

# Restaura configurações do terminal
ios_config "terminal length 24" ""
ios_config "terminal file prompt" ""

puts ""
puts "Coleta de log concluida com sucesso!"
puts "Arquivo salvo em: $arquivo_saida"
puts "Tamanho do arquivo: [file size $arquivo_saida] bytes"