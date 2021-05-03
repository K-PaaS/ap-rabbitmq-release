# PAAS-TA-RABBITMQ-RELEASE
bosh 2.0 PAAS-TA-RABBITMQ-RELEASE


# ON-DEMAND Configuration
------------------------
- haproxy :: 1 machine
- paasta-rmq-broker :: 1 machine
- rmq :: 0...# machine 


# Release 생성
------------------------

````
$ cd ~/
$ git clone https://github.com/PaaS-TA/rabbitmq-release.git
$ cd rabbitmq-release

# sh create.sh {RELEASE-NAEM} {VERSION}
$ sh create.sh paasta-rabbitmq 2.1.0
````
