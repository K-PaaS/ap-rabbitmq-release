echo \
'/****************************************************************
*	${1} : release-name	                                *
*	${2} : version						*	
*       # ./create-release  paasta-rabbitmq 2.1.0               *
****************************************************************/
'
bosh create-release --name ${1} --sha2 --force --tarball ./${1}-release-${2}.tgz --version ${2}

bosh ur ${1}-release-${2}.tgz

