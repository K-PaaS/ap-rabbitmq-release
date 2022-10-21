## rabbitmq-release create guide

based on https://github.com/pivotal-cf/cf-rabbitmq-release version : [v458.0.0](https://github.com/pivotal-cf/cf-rabbitmq-release/tree/v458.0.0)
based on https://github.com/pivotal-cf/cf-rabbitmq-multitenant-broker-release version : [v120.0.0](https://github.com/pivotal-cf/cf-rabbitmq-multitenant-broker-release/tree/v120.0.0)


### use file 
- pivotal-cf/cf-rabbitmq-release (* 디렉토리 하위 모든 파일)
```
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── Gemfile
├── Gemfile.lock
├── LICENSE
├── NOTICE
├── OSL
├── README.md --> README-pivotal.md
├── * Rakefile/
├── * config/
├── * jobs/
├── * manifests/
├── * packages/
├── * releases/
├── * scripts/
├── * spec/
└── * src/
```

- pivotal-cf/cf-rabbitmq-multitenant-broker-release (* 디렉토리 하위 모든 파일)
```
├── config/
│   └── blobs.yml (파일의 내용을 복사하여 덧붙이기)
├── jobs/
│   ├── * broker-deregistrar/
│   ├── * broker-registrar/
│   └── * rabbitmq-service-broker/
├── packages/
│   ├── * cf-rabbitmq-multitenant-broker-golang/
│   └── * rabbitmq-service-broker/
└── src/
    ├── * rabbitmq-service-broker/
    └── * rabbitmq-syslog-aggregator/
```

### 추가 작업
- $ vi .gitignore
```diff
config/dev.yml
config/private.yml
releases/*.tgz
+*.tgz
dev_releases
blobs
.blobs
.idea
.dev_builds
.final_builds/jobs/**/*.tgz
.final_builds/packages/**/*.tgz
coverage
/repos
releases/**/*.tgz
.DS_Store
*.swp
*~
*#
#*
rspec.xml
*.iml
-pkg
```
- $ vi jobs/rabbitmq-haproxy/spec
```diff
---
name: rabbitmq-haproxy

packages:
 - haproxy
 - rabbitmq-common

properties:
+  rabbitmq-haproxy.cce_enable:
+    defualt: false
+  rabbitmq-haproxy.backend_ca_file:
+    default: ''
+  rabbitmq-haproxy.ssl_cert:
+    default: ''
+  rabbitmq-haproxy.ssl_private_key:
+    default: ''
  rabbitmq-haproxy.do-not-configure-syslog:
    default: false
    description: "The haproxy_syslog.conf file will not be configured (can be used if you configure syslog-release)"

templates:
  rabbitmq-haproxy.init.erb:  bin/rabbitmq-haproxy.init
  haproxy.config.erb:         haproxy.config
  known-packages.bash:        bin/known-packages.bash
  pre-start.bash.erb:         bin/pre-start
  haproxy_syslog.conf:        config/haproxy_syslog.conf
+  backend-ca-certs.erb:       config/backend-ca-certs.pem
+  ssl-pem.erb:                config/ssl.pem

........
........
```

$ jobs/rabbitmq-haproxy/templates/backend-ca-certs.erb
```diff
+<% if p("rabbitmq-haproxy.cce_enable") %>
+<%
+if_p("rabbitmq-haproxy.backend_ca_file") do |pem|
+%>
+<%= pem %>
+<%
+end
+%>
+<% end %>
```

- $ jobs/rabbitmq-haproxy/templates/haproxy.config.erb

```diff
........
........

 <% ports.each do |port| %>
frontend input-<%= port %>
+    <% if p("rabbitmq-haproxy.cce_enable") && port == 5671 %>
+	bind :<%= port %>  ssl crt /var/vcap/jobs/rabbitmq-haproxy/config/ssl.pem
+    <% else %>
	bind :<%= port %>
+    <% end %>
        default_backend output-<%= port %>
 <%  timeouts.each do |index,timeout| %>
        <%  if index.to_i == port %>
        timeout client <%= timeout %>
        timeout server <%= timeout %>
        <%  end %>
 <%  end %>	

backend output-<%= port %>
        mode tcp
        balance leastconn
 <% ips.each_with_index do |ip, idx| %>
-	server node<%= idx %> <%= ip %>:<%= port %> check inter 5000
+    <% if p("rabbitmq-haproxy.cce_enable") %>
+        <% if port == 5671 %>
+        server node<%= idx %> <%= ip %>:<%= port %> check inter 5000 ssl verify required ca-file /var/vcap/jobs/rabbitmq-haproxy/config/backend-ca-certs.pem
+	<% else %>
+        server node<%= idx %> <%= ip %>:<%= port %> check inter 5000
+        <% end %>
+    <% else %>
+        server node<%= idx %> <%= ip %>:<%= port %> check inter 5000
+    <% end %>
 <% end %>
 <% end %>
```

- $ vi jobs/rabbitmq-haproxy/templates/ssl-pem.erb
```diff
+<% if p("rabbitmq-haproxy.cce_enable") %>
+<%= p("rabbitmq-haproxy.ssl_cert") %>
+<%= p("rabbitmq-haproxy.ssl_private_key") %>
+<% end %>
```

- $ vi jobs/rabbitmq-server/spec
```diff
........
........

properties:
  rabbitmq-server.version:
    description: "Version of RabbitMQ to use"
    default: "3.8"

+ rabbitmq-server.cce_enable:
  rabbitmq-server.ssl.enabled:
    default: false
    description: "Use TLS listeners. Will not accept non-TLS connections"

........
........
```

- $ vi jobs/rabbitmq-server/templates/config-files/11-tlsConfig.conf.erb

```diff
........
........
stomp.listeners.tcp = none
 <% end -%>

+<% if p("rabbitmq-server.cce_enable") -%>
+listeners.tcp.default = _vm_ip:5672
+<% end -%>
listeners.ssl.1 = 5671
mqtt.listeners.ssl.1 = 8883
stomp.listeners.ssl.1 = 61614
........
........
```


- $ vi jobs/rabbitmq-server/templates/rabbitmq-config-vars.bash.erb
```diff
........
........
export ERLANG_MAJOR_VERSION='<%= p('rabbitmq-server.erlang_major_version') %>'
export ERL_INETRC_HOSTS='<%= inetrc_hosts %>'
export RMQ_SERVER_VERSION='<%= p('rabbitmq-server.version') %>'


+<% if p("rabbitmq-server.ssl.enabled") %>
+<% if p("rabbitmq-server.cce_enable") %>
+  echo "###########################################################"
+  echo "# CE enable "
+  _vm_ip=`ip route get 8.8.8.8 | awk '{print $NF; exit}'`
+  sed -i "s/_vm_ip/$_vm_ip/" /var/vcap/jobs/rabbitmq-server/etc/conf.d/11-tlsConfig.conf
+  echo "###########################################################"
+<% else %>
+  vi -c "%g/listeners.tcp.default/d" -c "wq" /var/vcap/jobs/rabbitmq-server/etc/conf.d/11-tlsConfig.conf 
+<% end %>
+<% end %>
```

