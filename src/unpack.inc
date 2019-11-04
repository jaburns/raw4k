unpackAndEnterPayload:
        push eax
        mov edi, eax
        mov eax, payloadData
        movzx ebx, byte [eax]
        lea edx, dword [eax+1]
        xor esi, esi
        mov ecx, esi
    .dictLoop:
        movzx eax, byte [edx]
        mov dword [esp+ecx*4-2048], edx
        inc edx
        add edx, eax
        inc ecx
        cmp ecx, ebx
        jl .dictLoop
    .unpackLoop:
        mov al, byte [edx]
        inc edx
        cmp al, 255 
        jne .copyByte
        movzx eax, byte [edx]
        inc edx
        mov ecx, dword [esp+eax*4-2048]
        movzx ebx, byte [ecx]
        inc ecx
        test ebx, ebx
        je .endUnpackLoop
        add esi, ebx
    .copyFromDictLoop:
        mov al, byte [ecx]
        mov byte [edi], al
        inc edi
        inc ecx
        dec ebx
        test ebx, ebx
        jg .copyFromDictLoop
        jmp .endUnpackLoop
    .copyByte:
        mov byte [edi], al
        inc edi
        inc esi
    .endUnpackLoop:
        cmp edx, the_end
        jb .unpackLoop
        ret ; pop eax, jmp eax