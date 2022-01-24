// LANCIARE IL SITO (VERSIONE DI PRODUZIONE/BUILD)

// Cambiare directory andando nella root dei file
// del progetto build. In VueJS e la cartella /dist
$ cd /indirizzo/alla/directory/dist

// Installare un virtual server di HTML & JavaScript
$ sudo apt-get install http.server

// Lanciare il server con Python 2.*
$ python -m SimpleHTTPServer 1337

// Lanciare il server con Python 3.*
$ python -m http.server 1337

// o in alternativa si puo usare http-server di NodeJS
$ npm install http-server -g
$ http-server /indirizzo/alla/directory/dist -p 1337

// Sfogliare la pagina nell'indirizzo
$ firefox localhost:1337/