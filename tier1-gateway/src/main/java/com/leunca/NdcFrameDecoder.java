package com.leunca;

import io.netty.handler.codec.ByteToMessageDecoder;
import java.util.List;
import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelHandlerContext;


public class NdcFrameDecoder extends ByteToMessageDecoder {
    @Override
    protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) {
        // Implement framing logic based on NDC protocol
    }
}

