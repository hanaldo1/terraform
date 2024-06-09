# Wireguard 서버
: wg-easy 프로젝트를 활용한 Docker 기반 Wireguard VPN 서버 구축 

- AWS Lightsail
- Docker
  - [wg-easy](https://github.com/wg-easy/wg-easy)

## 1. Prerequirements
1. Lightsail 인스턴스용 Keypair 생성

    > $ mkdir -p ssh

    > $ ssh-keygen -t rsa
    
    - 키 파일 생성 시 경로는 `<wireguard-server terraform 모듈 경로>/ssh/lightsail_key` 로 지정 필요

## 2. 프로비저닝
> $ terraform init

> $ terraform apply

## 3. wireguard UI 접근
- `http://<Lightsail Static IP 주소>:51821`

![wg-ui](./wg-ui.png)