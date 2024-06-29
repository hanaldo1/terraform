# EKS
: terraform 을 활용하여 AWS EKS 클러스터 구축 (기 제공되는 모듈 사용하지 않음)

- network 모듈
  - EKS 클러스터 구성을 위해 필요한 네트워크 레벨 리소스 프로비저닝
  - VPC, Subnet, RouteTable, NACL, Security Group, Internet Gateway
- cluster 모듈
  - EKS 클러스터 및 Worker 노드 리소스 프로비저닝
  - EKS, Autoscaling Group, Instance Profile, Launch Template
- test-page 모듈
  - 생성이 완료된 EKS 클러스터에 테스트 팟을 띄우고 정상 실행 여부 확인
  - Hashicorp 에서 제공하는 [http-echo](https://hub.docker.com/r/hashicorp/http-echo/) 컨테이너 사용

  ![test-page](./test-page.png)

----

**EKS 클러스터 구성 시 이슈 발생했던 부분**
1. Egress 를 전부 허용하는 것이 아니라 필요 포트에 대해서만 허용 가능하도록 설정 하는 과정에서 통신 안되는 이유 발생
  
    - 임시적으로 전체 허용 이후, 필요 설정 들 하나하나 추가하면서 통신 가능 여부 확인해보는 방법으로 해결

2. VPC 의 호스트 이름 DNS 지원 옵션을 활성화 하지 않아 노드가 클러스터에 조인하지 못하는 이슈 발생
  
    - 참고: https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/troubleshooting.html#worker-node-fail
  
    - 추가적으로 띄운 노드에 `kubernetes.io/cluster/<클러스터 이름>` 태그 붙여주지 않음

3. 테스트 페이지 띄울 시, Worker 노드가 t3.micro 라면 해당 노드가 허용할 수 있는 최대 팟 개수가 4개이기 때문에 팟이 실행되지 않음
    
    - 기본적으로 EKS 가 생성된 노드 별 AWS CNI 팟과 kube-proxy 팟이 각각 1개씩 그리고 CoreDNS 팟 2개가 띄워지기 때문
    - 임시적으로 CoreDNS 팟 replica 를 1로 내리면 테스트 팟 정상 실행 후, 테스트 페이지 확인 가능

----

**TODO**
- aws-auth 생성
  - Configmap 대신 EKS Access Entry 사용해보기
- 중복 코드 제거 및 리팩토링
- worker 노드 실행 Cloud-init 파일 재 검토
- 부족한 주석 및 설명 추가