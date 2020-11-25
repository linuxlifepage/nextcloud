
_Давайте рассмотрим такую ситуацию, что у нас есть обычный VPS(к примеру бесплатный от оракла),
и у нас так же есть второй наш сервер ДОМАШНИЙ Некстклауд. 
И мы хотим получить к нему доступ через наш приватный сервер VPS, да еще чтобы у него был
сертификат, и работал он на каком-нибудь отдельном поддомене, к примеру homenextcloud.domain.com.
КАК ЭТО СДЕЛАТЬ? На самом деле все просто, через OpenVPN и Nginx с проксированием._

Сейчас у нас есть уже установленный на VPS приватный ВПН OpenVPN. Если у вас он еще не установлен,
то вперед смотреть видео https://www.youtube.com/watch?v=WNryfgMM-WA

1) Для начала заходим на наше сервер OVPN по ssh

2) Запускаем наш скрипт openVPN из домашней директории

   ```sudo ./openvpn-install.sh ```   		#для Ubuntu 16 и старше
   ```sudo ./openvpn-ubuntu-install.sh ```    #для Ubuntu 18 и младше
   Выбираем первый пункт: Add a new user
   
3) Копируем конфиг с сервера OVPN на сервер НК
   *сначала копируем на ПК, а потом на сервер

   ```scp ubuntu@158.101.111.111:/home/ubuntu/nextcloud.ovpn ./```
   ```scp nextcloud.ovpn user@192.168.1.9:/home/user/```

4) Ставим на сервер с НК OpenVPN

```sudo apt update && sudo apt install openvpn -y```

5) Скопируем наш конфиг в системную директорию
```sudo cp ~/nextcloud.ovpn /etc/openvpn/nextcloud.conf```

6) Отредактируем опенвпн
```sudo vim /etc/default/openvpn```

И добавим строку
```AUTOSTART="nextcloud"```
*эта директива также автоматом рестартует подключение если связь была потеряна

7) Узнаем наш внешний IP (так как мы за NAT, то выдаст IP провайдера)
```wget -O - -q icanhazip.com```

8) Перезагружаемся ```sudo reboot``` и проверяем наш IP, если он совпадает с сервером ВПН, то радуемся:)
```ssh user@192.168.1.9```
```wget -O - -q icanhazip.com```

Также узнаем наш IP интерфейса VPN:
```ip a | grep tun0 ```       # выдаст что-то типа того 10.8.0.4

Также проверяем доступен ли наш nextcloud по внутреннему интерфейсу сети (НЕ ВПН):
```http:// 192.168.1.9```

9) Проверяем доступность нашего некстклауда на сервере ВПН: 
```curl http://10.8.0.4```

Должна быть портянка:

```<!DOCTYPE html>
<html class="ng-csp" data-placeholder-focus="false" lang="en" data-locale="en" >
	<head
 data-requesttoken="NLikcGP9hUBVOmPa0Qlbk9Kr7PtZYmYGnT+FySejh2g=:DJfyFDqZwzYEAymY4Gc9wYbKtcgbDRww2HGxmH75wA4=">
		<meta charset="utf-8">
		<title>
		Nextcloud		</title>
```
    
10) Открываем порт в Oracle:
В нетворк - секьюрити лист открываем 8555

Далее на сервере также открываем:

```sudo iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 8555 -j ACCEPT```

*ЕСЛИ У ВАС НЕТ ОРАКЛА, А ПРОСТОЙ VPS, то открываем порт через ufw:

```sudo ufw allow 8555/tcp```

Отредактируем и добавим рядом с 22 наше правило:

```sudo vim /etc/iptables/rules.v4```

добавить эту строку

```-A INPUT -p tcp -m state --state NEW -m tcp --dport 8555 -j ACCEPT```

***ЖЕЛАТЕЛЬНО ПЕРЕЗАГРУЗИТЬСЯ***

11) Редактируем наш конфиг хоста Nginx (у меня это ncloud.linuxlife.page)
    И добавляем в самый низ (не забудьте вписать свой домен в SSL и также IP впн домаш некстклауда)

```server {
    listen 0.0.0.0:8555 ssl http2;
    listen [::]:8555 ssl http2;

    # max file upload size
    client_max_body_size 2500M;

    # ncloud.linuxlife.website
    server_name ncloud.linuxlife.website;

    access_log /var/log/nginx/nextcloud.home.access;
    error_log /var/log/nginx/nextcloud.home.error;

    # configure the ssl certificate
    ssl_certificate /etc/letsencrypt/live/ncloud.linuxlife.website/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ncloud.linuxlife.website/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/ncloud.linuxlife.website/chain.pem;

    # proxy requests to Nextcloud which is listening on port 80
    location / {
        include proxy_params; # include necessary headers
        proxy_pass http://10.8.0.3:80;
        proxy_redirect http:// $scheme://;
    }

}
```

Сохраняем, перезагружаем nginx: 

```sudo service nginx restart```

И заходим в браузер:
```https://ncloud.linuxlife.website:8555```

12) Указываем в файле конфигурации config.php домашнего НК строку
```'overwritehost' => 'ncloud.linuxlife.website:8555',```

Тутже добавим наш домен в одобренные:
```'trusted_domains' => 
  array (
    0 => '192.168.1.9',
    1 => '10.8.0.3',
    2 => 'ncloud.linuxlife.website'  
  ),
  ```

13) Если вы решили пересоздать в Докер-композ приложение (к примеру некстклауд), то
	докер может ругаться, из-за того что openvpn мониторит сеть:

```
Creating network "nextcloud_test_nextcloud" with the default driver
ERROR: could not find an available, non-overlapping IPv4 address pool among the defaults to assign to the network
```

Решение простое:
```sudo service openvpn stop```

Дальше поднять свое приложение:
```sudo docker-compose up -d```
```sudo service openvpn start```


***ИТОГ:***
Таким способом мы можем прокинуть любое веб-приложение со своего домашнего сервера или виртуалки






