# usar o cloudflared - e criar um tunel para: OBWS que será um servidor que recebe dados de telemetria!
-----------------
- use o cloudflared -> e no dominio: obws.fun - um apontamento A -> como: a.obws.fun
- e suba o servidor que recebe dados criptografados!
- para descriptografar usar a chave abaixo:
ws/server_x25519.key 
-----BEGIN PRIVATE KEY-----
MC4CAQAwBQYDK2VuBCIEILCNHIDBnbnrhrxWAdUeVAxuTWiDS0KJpkzHr07cYnVI
-----END PRIVATE KEY-----
-------------
ou seja termos na web -> a.obws.fun como web server -> usando o nginx com proxy reverse!
- todos os dados recebidos devem ser recebidos, em: a.obws.fun -> e devem encaminhar para o backend -> /opt/bws/ dentro deve ter o backend em golang, que recebe os dados da web: a.obws.fun | já no: obws.fun - deve ter um arquivo HTML com 404 ERROR
--------
crie e suba tudo!

