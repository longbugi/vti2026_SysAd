#!/bin/bash

#Create new repository on GitHub
git init
git config --global user.email "yen.nguyenhoacat@gmail.com"
git config --global user.name "yennhc"
echo "# demo-02" > README.md
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin <repository-url>
git push -u origin main

#Authentication GitHub with token
git config --global credential.helper store



#Demo repository on GitHub
#echo "# demo-02" >> README.md
#git init
#git add README.md
#git commit -m "first commit"
#git branch -M main
#git remote add origin https://github.com/yennhc/demo-02.git
#git push -u origin main

#…or push an existing repository from the command line
#git remote add origin https://github.com/yennhc/demo-02.git
#git branch -M main
#git push -u origin main