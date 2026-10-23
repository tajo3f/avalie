# QR Code e NFC

O TAJO Avalie usa **a mesma URL pública permanente** para QR Code e NFC.

Exemplo:

```text
https://avalie.tajodigital.com.br/mercado-central/caixa-04
```

## QR Code

A URL é convertida em QR e impressa na plaquinha.

## NFC

A mesma URL pode ser gravada em uma tag NFC do tipo URL/NDEF. Ao aproximar um celular compatível, o navegador abre a mesma tela de avaliação.

O sistema não precisa saber se o acesso veio do QR ou do NFC para registrar a avaliação. Se futuramente for importante medir a origem, crie URLs com um parâmetro de origem ou códigos públicos separados que resolvam para o mesmo ponto.

## Regra importante

O link representa o **ponto de atendimento**, não o funcionário. O turno ativo define quem estava naquele ponto no momento da avaliação. Isso evita reimprimir a plaquinha quando muda o operador.
