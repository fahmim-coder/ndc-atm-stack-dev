# **Implementing High-Performance Netty Server on Ubuntu 24.04 (VirtualBox)**

Here's a complete step-by-step guide to deploy your Netty socket server on a Ubuntu 24.04 VirtualBox guest, including all necessary configurations and optimizations.

## **1. VirtualBox Guest Setup**

### **1.1 Ubuntu 24.04 Base Configuration**
```bash
# Update system and install essentials
sudo apt update && sudo apt upgrade -y
sudo apt install -y openjdk-17-jdk maven git net-tools htop

# Verify Java
java -version  # Should show OpenJDK 17
```

### **1.2 Network Configuration**
1. In VirtualBox settings:
   - Set **Network Adapter** to **Bridged Adapter**
   - Enable **Promiscuous Mode**: "Allow All"
2. Configure static IP (optional but recommended):
```bash
sudo nano /etc/netplan/00-installer-config.yaml
```
```yaml
network:
  ethernets:
    enp0s3:
      dhcp4: no
      addresses: [192.168.1.100/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
```
Apply changes:
```bash
sudo netplan apply
```

## **2. Build and Run Netty Server**

### **2.1 Clone and Build**
```bash
git clone https://github.com/your-repo/netty-server.git
cd netty-server
mvn clean package
```

### **2.2 Systemd Service Setup**
Create a service file:
```bash
sudo nano /etc/systemd/system/netty-server.service
```
```ini
[Unit]
Description=Netty Socket Server
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/netty-server
ExecStart=/usr/bin/java -Xms2g -Xmx4g -XX:+UseG1GC -jar target/netty-server.jar
Restart=always
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable netty-server
sudo systemctl start netty-server
```

Check status:
```bash
sudo systemctl status netty-server
journalctl -u netty-server -f  # Follow logs
```

## **3. OS Tuning for High Performance**

### **3.1 Kernel Parameters**
```bash
sudo nano /etc/sysctl.conf
```
Add these lines:
```conf
# Socket buffers
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216

# Connection handling
net.ipv4.tcp_max_syn_backlog=65535
net.core.somaxconn=65535
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30

# File descriptors
fs.file-max=1000000
```

Apply changes:
```bash
sudo sysctl -p
```

### **3.2 User Limits**
```bash
sudo nano /etc/security/limits.conf
```
Add:
```conf
* soft nofile 1000000
* hard nofile 1000000
* soft nproc 65535
* hard nproc 65535
```

### **3.3 Firewall Configuration**
```bash
sudo ufw allow 8081/tcp
sudo ufw enable
```

## **4. Monitoring Setup**

### **4.1 Install Prometheus Node Exporter**
```bash
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvf node_exporter-*.tar.gz
sudo mv node_exporter-*.linux-amd64/node_exporter /usr/local/bin/
```

Create service:
```bash
sudo nano /etc/systemd/system/node_exporter.service
```
```ini
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```

Start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

### **4.2 Netty Metrics with Micrometer**
Add to your `pom.xml`:
```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-core</artifactId>
    <version>1.11.5</version>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
    <version>1.11.5</version>
</dependency>
```

Instrument your server:
```java
// In your main class
MeterRegistry registry = new PrometheusMeterRegistry(PrometheusConfig.DEFAULT);
Metrics.addRegistry(registry);

// Add to pipeline
ch.pipeline().addLast("metrics", new ChannelMetricsHandler(registry));
```

Expose metrics endpoint:
```java
// Add this to your server initialization
new Thread(() -> {
    HttpServer.create()
        .port(8082)
        .route(routes -> routes.get("/metrics", 
            (req, res) -> res.send(registry.scrape())))
        .bindNow()
        .onDispose()
        .block();
}).start();
```

## **5. Load Testing Setup**

### **5.1 Install JMeter**
```bash
sudo apt install -y jmeter
```

### **5.2 Create Test Plan**
Save this as `load_test.jmx`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.6.2">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Netty Load Test" enabled="true">
      <stringProp name="TestPlan.comments"></stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.tearDown_on_shutdown">true</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments" guiclass="ArgumentsPanel" testclass="Arguments" testname="User Defined Variables" enabled="true">
        <collectionProp name="Arguments.arguments"/>
      </elementProp>
      <stringProp name="TestPlan.user_define_classpath"></stringProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Thread Group" enabled="true">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControlPanel" testclass="LoopController" testname="Loop Controller" enabled="true">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <intProp name="LoopController.loops">-1</intProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">1000</stringProp>
        <stringProp name="ThreadGroup.ramp_time">60</stringProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
        <stringProp name="ThreadGroup.duration">300</stringProp>
        <stringProp name="ThreadGroup.delay"></stringProp>
        <boolProp name="ThreadGroup.same_user_on_next_iteration">true</boolProp>
      </ThreadGroup>
      <hashTree>
        <TCPSampler guiclass="TCPSamplerGui" testclass="TCPSampler" testname="TCP Request" enabled="true">
          <stringProp name="TCPSampler.server">192.168.1.100</stringProp>
          <stringProp name="TCPSampler.port">8081</stringProp>
          <stringProp name="TCPSampler.timeout">5000</stringProp>
          <stringProp name="TCPSampler.request">00000006000174657374</stringProp> <!-- MSG_AUTH -->
          <boolProp name="TCPSampler.reUseConnection">true</boolProp>
          <boolProp name="TCPSampler.nodelay">true</boolProp>
          <boolProp name="TCPSampler.closeConnection">false</boolProp>
        </TCPSampler>
        <hashTree/>
        <ResultCollector guiclass="StatVisualizer" testclass="ResultCollector" testname="Aggregate Report" enabled="true">
          <boolProp name="ResultCollector.error_logging">false</boolProp>
          <objProp>
            <name>saveConfig</name>
            <value class="SampleSaveConfiguration">
              <time>true</time>
              <latency>true</latency>
              <timestamp>true</timestamp>
              <success>true</success>
              <label>true</label>
              <code>true</code>
              <message>true</message>
              <threadName>true</threadName>
              <dataType>true</dataType>
              <encoding>false</encoding>
              <assertions>true</assertions>
              <subresults>true</subresults>
              <responseData>false</responseData>
              <samplerData>false</samplerData>
              <xml>false</xml>
              <fieldNames>true</fieldNames>
              <responseHeaders>false</responseHeaders>
              <requestHeaders>false</requestHeaders>
              <responseDataOnError>false</responseDataOnError>
              <saveAssertionResultsFailureMessage>true</saveAssertionResultsFailureMessage>
              <assertionsResultsToSave>0</assertionsResultsToSave>
              <bytes>true</bytes>
              <sentBytes>true</sentBytes>
              <url>true</url>
              <threadCounts>true</threadCounts>
              <idleTime>true</idleTime>
              <connectTime>true</connectTime>
            </value>
          </objProp>
          <stringProp name="filename">result.csv</stringProp>
        </ResultCollector>
        <hashTree/>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
```

Run test:
```bash
jmeter -n -t load_test.jmx -l results.jtl
```

## **6. Performance Verification**

### **6.1 Monitor Connections**
```bash
# Real-time connection count
watch -n 1 "netstat -an | grep 8081 | wc -l"

# Detailed connection states
ss -s
```

### **6.2 JVM Monitoring**
```bash
# Install VisualVM
sudo apt install -y visualvm
visualvm --jdkhome /usr/lib/jvm/java-17-openjdk-amd64
```

Connect to your Netty server process to monitor:
- Threads
- Heap usage
- GC activity

## **Next Steps Checklist**

1. [ ] Implement TLS encryption (see below)
2. [ ] Set up Kafka integration
3. [ ] Configure Grafana dashboard
4. [ ] Implement automated failover

### **Adding TLS Encryption**
Modify your Netty server initialization:
```java
SslContext sslContext = SslContextBuilder
    .forServer(new File("server.crt"), new File("server.key"))
    .protocols("TLSv1.3")
    .ciphers(null, IdentityCipherSuiteFilter.INSTANCE)
    .build();

bootstrap.childHandler(new ChannelInitializer<SocketChannel>() {
    @Override
    protected void initChannel(SocketChannel ch) {
        ch.pipeline().addLast(
            sslContext.newHandler(ch.alloc()),
            new CustomProtocolDecoder(),
            new BusinessLogicHandler()
        );
    }
});
```

Would you like me to provide detailed steps for any of these next steps? For example:
- Complete TLS certificate generation and configuration
- Kafka producer/consumer implementation details
- Grafana dashboard setup with Netty metrics
- High-availability cluster configuration
