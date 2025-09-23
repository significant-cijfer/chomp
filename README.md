# Chomp

Discussed this funny game called [Chomp](https://en.wikipedia.org/wiki/Chomp) in TW for proofs/problemsolving  
This program tries to find the wining starting point, maybe in the future ill try to display the entire path  

Example usage:
```sh
# Width x Height
# Please do use the release flag, optimizations have been implemented, but sizes larger than 10x10, will still take a long time to compute
zig build run --release=safe -- 4 4
```
