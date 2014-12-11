rsafe
=====
a place to keep your passwords  
still under development  
but if you want to have a mess around
```
git clone https://github.com/ndxbxrme/rsafe.git
cd rsafe
npm install
npm link
```
then you should be off to the races  

```
rsafe setup
rsafe login
```
set some data using `rsafe set`  
use dot notation to add data to subkeys, eg.
```
rsafe set heroku.mywebsite.username
rsafe set heroku.mywebsite.password
```
check the keys you have set using `rsafe list`  
```
rsafe list heroku
```
get your data by specifying the key  
```
rsafe get heroku.mywebsite.password
```
etc  
have fun
