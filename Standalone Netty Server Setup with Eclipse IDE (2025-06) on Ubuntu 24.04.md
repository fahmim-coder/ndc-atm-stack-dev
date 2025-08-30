# **Standalone Netty Server Setup with Eclipse IDE (2025-06) on Ubuntu 24.04**

Here's the complete step-by-step guide using Eclipse IDE for Enterprise Java and Web Developers (2025-06) to create a production-ready Netty TCP server:

## **1. Environment Setup**

### **1.1 Install Prerequisites**
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y openjdk-21-jdk maven git
```

### **1.2 Configure Eclipse IDE**
1. Launch Eclipse IDE 2025-06
2. Go to **Window > Preferences**
   - Set **Java > Installed JREs** to JDK 21
   - Set **Maven > Installation** to your system Maven

## **2. Create Netty Project in Eclipse**

### **2.1 New Maven Project**
1. **File > New > Maven Project**
2. Check "Create a simple project"
3. Enter:
   - Group ID: `com.yourcompany`
   - Artifact ID: `netty-server`
   - Version: `1.0.0`
4. Click Finish

### **2.2 Configure pom.xml**
Right-click `pom.xml` > **Open With > Text Editor** and replace with:

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.yourcompany</groupId>
    <artifactId>netty-server</artifactId>
    <version>1.0.0</version>
    
    <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <maven.compiler.release>21</maven.compiler.release>
        <netty.version>4.1.97.Final</netty.version>
    </properties>
    
    <dependencies>
        <!-- Netty Core -->
        <dependency>
            <groupId>io.netty</groupId>
            <artifactId>netty-all</artifactId>
            <version>${netty.version}</version>
        </dependency>
        
        <!-- Linux Optimization -->
        <dependency>
            <groupId>io.netty</groupId>
            <artifactId>netty-transport-native-epoll</artifactId>
            <version>${netty.version}</version>
            <classifier>linux-x86_64</classifier>
        </dependency>
        
        <!-- Logging -->
        <dependency>
            <groupId>org.slf4j</groupId>
            <artifactId>slf4j-simple</artifactId>
            <version>2.0.7</version>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-shade-plugin</artifactId>
                <version>3.5.0</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                        <configuration>
                            <transformers>
                                <transformer implementation="org.apache.maven.plugins.shade.resource.ManifestResourceTransformer">
                                    <mainClass>com.yourcompany.NettyServer</mainClass>
                                </transformer>
                            </transformers>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
```

## **3. Implement Netty Server**

### **3.1 Create Main Class**
Right-click `src/main/java` > **New > Class**:
- Package: `com.yourcompany`
- Name: `NettyServer`

```java
package com.yourcompany;

import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.*;
import io.netty.channel.epoll.EpollEventLoopGroup;
import io.netty.channel.epoll.EpollServerSocketChannel;
import io.netty.channel.socket.SocketChannel;

public class NettyServer {
    private static final int PORT = 8081;
    
    public static void main(String[] args) throws Exception {
        // Configure thread pools
        EventLoopGroup bossGroup = new EpollEventLoopGroup(1);
        EventLoopGroup workerGroup = new EpollEventLoopGroup();
        
        try {
            ServerBootstrap bootstrap = new ServerBootstrap();
            bootstrap.group(bossGroup, workerGroup)
                   .channel(EpollServerSocketChannel.class)
                   .option(ChannelOption.SO_BACKLOG, 100000)
                   .childOption(ChannelOption.TCP_NODELAY, true)
                   .childOption(ChannelOption.SO_KEEPALIVE, true)
                   .childHandler(new ChannelInitializer<SocketChannel>() {
                       @Override
                       protected void initChannel(SocketChannel ch) {
                           ch.pipeline().addLast(new SimpleChannelInboundHandler<String>() {
                               @Override
                               protected void channelRead0(ChannelHandlerContext ctx, String msg) {
                                   System.out.println("Received: " + msg.trim());
                                   ctx.writeAndFlush("ACK: " + msg);
                               }
                               
                               @Override
                               public void channelActive(ChannelHandlerContext ctx) {
                                   System.out.println("Client connected: " 
                                       + ctx.channel().remoteAddress());
                               }
                               
                               @Override
                               public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
                                   cause.printStackTrace();
                                   ctx.close();
                               }
                           });
                       }
                   });
            
            // Start server
            ChannelFuture future = bootstrap.bind(PORT).sync();
            System.out.println("Server started on port " + PORT);
            
            // Add shutdown hook
            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                System.out.println("Shutting down...");
                bossGroup.shutdownGracefully();
                workerGroup.shutdownGracefully();
            }));
            
            future.channel().closeFuture().sync();
        } finally {
            bossGroup.shutdownGracefully();
            workerGroup.shutdownGracefully();
        }
    }
}
```

### **3.2 Build Project**
Right-click project > **Run As > Maven Build...**
- Goals: `clean package`
- Click Run

## **4. System Configuration**

### **4.1 OS Tuning**
Run in terminal:
```bash
# File descriptors
sudo nano /etc/security/limits.conf
```
Add:
```conf
* soft nofile 1000000
* hard nofile 1000000
```

```bash
# Network settings
sudo nano /etc/sysctl.conf
```
Add:
```conf
net.ipv4.tcp_tw_reuse = 1
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
fs.file-max = 1000000
```

Apply changes:
```bash
sudo sysctl -p
ulimit -n 1000000
```

## **5. Deployment**

### **5.1 Create systemd Service**
```bash
sudo nano /etc/systemd/system/netty-server.service
```
```ini
[Unit]
Description=Netty TCP Server
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/path/to/eclipse/workspace/netty-server/target
ExecStart=/usr/bin/java \
  -Xms2g -Xmx4g \
  -XX:+UseZGC \
  -XX:+ZGenerational \
  -Dio.netty.allocator.type=pooled \
  -Dio.netty.tryReflectionSetAccessible=true \
  -jar netty-server-1.0.0.jar
Restart=always
RestartSec=5
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
```

### **5.2 Enable Service**
```bash
sudo systemctl daemon-reload
sudo systemctl enable netty-server
sudo systemctl start netty-server
sudo systemctl status netty-server
```

## **6. Testing**

### **6.1 Manual Test**
```bash
nc localhost 8081
> Hello
< ACK: Hello
```

### **6.2 Monitor Connections**
```bash
watch -n 1 "netstat -an | grep 8081 | wc -l"
```

## **7. Eclipse Development Tips**

1. **Debugging**:
   - Right-click `NettyServer.java` > **Debug As > Java Application**
   - Set breakpoints in channel handlers

2. **Protocol Development**:
   - Create new classes in `com.yourcompany.protocol`
   - Implement `ChannelInboundHandlerAdapter` for custom protocols

3. **Performance Profiling**:
   - Use **Eclipse TPTP** plugin for thread analysis
   - Right-click project > **Profile As > Java Application**

Would you like me to add:
1. TLS/SSL configuration in Eclipse?
2. JMeter test plan integration?
3. Kubernetes deployment setup?
4. Custom protocol buffer implementation?
