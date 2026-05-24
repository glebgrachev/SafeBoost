class VpnConfig {
  // VLESS URI передаётся напрямую — flutter_vless парсит его сам
  static const String vlessUri =
      String.fromEnvironment(
        'VPN_URI',
        defaultValue:
            'vless://27c81883-80a5-4756-aece-34780ecc1faa@31.76.227.67:443'
            '?type=tcp&encryption=none&security=reality'
            '&pbk=uFhNqyddJHwxGR61YlpPl9gwC_FhmIbEadXvj4Rb3hI'
            '&fp=chrome&sni=lumen.yandex.ru&sid=26607a380c'
            '&spx=%2F&flow=xtls-rprx-vision#testRU_user1',
      );
}