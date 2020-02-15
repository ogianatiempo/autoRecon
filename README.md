# autoRecon

Automatic subdomain and directory enumeration for bugbounty.
Based on nahamsec's [lazyrecon](https://github.com/nahamsec/lazyrecon)

## Instalation

Requires to install nahamsec's bugbounty hacking tools:

- git clone https://github.com/nahamsec/bbht.git
- cd bbht
- chmod +x install.sh
- ./install.sh

Then, clone this repo and use it:

``` bash
./autoRecon.sh -d domain.com -e excluded.domain.com,other.domain.com
```
