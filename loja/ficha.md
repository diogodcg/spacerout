# Ficha da loja — Google Play (pt-BR)

Tudo o que o Play Console pede em **Presença na loja → Ficha principal da loja**. Textos em português do Brasil (idioma padrão do app). Limites conferidos por contagem de caracteres.

## Textos

**Nome do app** (30/30)
```
SpaceRout – Missões da Família
```

**Descrição curta** (80/80)
```
Tarefas de casa viram missões. A família cumpre, ganha moedas e resgata prêmios.
```

**Descrição completa** (1932/4000)
```
Tarefas de casa viram missão espacial! 🚀

O SpaceRout transforma a rotina da família em um jogo cooperativo. O responsável cadastra missões e prêmios; os astronautas da casa cumprem as missões, enviam uma foto como comprovação e trocam as moedas ganhas por prêmios combinados em família.

COMO FUNCIONA
1. Cadastre a missão: o responsável cria missões com moedas de recompensa e recorrência (pontual, diária ou semanal).
2. Cumpra e comprove: o astronauta cumpre a missão e envia uma foto direto pelo app.
3. Aprove e resgate: o responsável aprova, as moedas caem na conta e podem ser trocadas por prêmios da loja da família.

PARA OS RESPONSÁVEIS
• Crie missões e prêmios com moedas, recorrência e horário de lembrete
• Atribua uma missão a um ou a vários astronautas, ou deixe aberta para todos
• Aprove ou rejeite as comprovações enviadas
• Confirme a entrega dos prêmios resgatados
• Acompanhe o desempenho de cada astronauta no relatório
• Convide outros responsáveis e astronautas por e-mail

PARA OS ASTRONAUTAS
• Veja suas missões e envie a comprovação pela câmera ou pela galeria
• Acompanhe suas moedas
• Troque as moedas por prêmios na loja da família
• Receba lembretes das missões

AS MOEDAS SÃO UM JOGO
As moedas do SpaceRout são só pontos de gamificação: não valem dinheiro e não são convertidas em dinheiro. Os prêmios são definidos pela própria família, como tempo de tela, um passeio ou o que vocês combinarem.

GRÁTIS PARA COMEÇAR
O plano gratuito permite até 3 missões e 3 prêmios ativos ao mesmo tempo por família. Para quem precisa de mais, há uma assinatura opcional.

PRIVACIDADE E SEGURANÇA
• Sem anúncios
• Cada família tem seu espaço isolado das demais
• As fotos de comprovação ficam privadas, visíveis só para a família
• Entrada com sua conta Google: o SpaceRout não guarda sua senha
• Você pode excluir sua conta e seus dados direto no app

Dúvidas ou sugestões? Escreva para contato@spacerout.com.br.
```

**O que há de novo** — versão 0.1.0 (282/500)
```
Primeira versão do SpaceRout!

• Missões e prêmios para a família toda
• Comprovação por foto e aprovação pelo responsável
• Moedas, loja de prêmios e relatório por astronauta
• Lembretes de missão por notificação
• Convite de familiares por e-mail
• Exclusão de conta direto no app
```

## Imagens

| Item | Arquivo | Regra do Play |
|---|---|---|
| Ícone do app | `icone-512.png` | 512×512 PNG, até 1 MB, fundo cheio, sem cantos arredondados nem sombra (o Google aplica a máscara) |
| Imagem de destaque | `feature-graphic-1024x500.png` | 1024×500 PNG ou JPG, sem transparência |
| Screenshots de celular | `screenshots/01…07-*.png` (1080×1920) | mínimo 2, até 8; proporção 9:16 ou 16:9; lado menor ≥ 320 px e maior ≤ 3840 px |

O fonte editável da imagem de destaque é `feature-graphic.svg`. Regerar: `rsvg-convert -w 1024 -h 500 feature-graphic.svg -o feature-graphic-1024x500.png`.

### Screenshots (pasta `screenshots/`, ordem de upload)
Capturados no emulador em 1080×1920 (o Pixel 7 é 1080×2400, e o Play rejeita lado maior > 2× o menor), barra de status limpa (12:00, bateria cheia), com dados fictícios: família "Os Estrela", responsável Marina, astronautas Luna, Theo e Bia. A foto de comprovação é uma ilustração, não uma foto real.

1. `01-inicio-responsavel.png` — mascote Stellar e cartões-resumo
2. `02-missoes-responsavel.png` — missões com status e atribuição
3. `03-status-missoes.png` — comprovação com foto aguardando aprovação
4. `04-missoes-astronauta.png` — visão da criança com estados variados
5. `05-loja-astronauta.png` — saldo e resgate de prêmios
6. `06-relatorio.png` — desempenho por astronauta
7. `07-inicio-astronauta.png` — boas-vindas e saldo do astronauta

## Categorização e contato

| Campo | Valor |
|---|---|
| Tipo | Aplicativo |
| Categoria | Paternidade (Parenting); alternativa: Produtividade |
| E-mail de contato | contato@spacerout.com.br |
| Site | https://spacerout.com.br |
| Política de privacidade | https://spacerout.com.br/privacidade.html |
| Idioma padrão | Português (Brasil) |

## Pendências ligadas à publicação
- Depois que o app estiver publicado, trocar "Baixar na Play Store (em breve)" no `docs/index.html` pelo link da loja.
- Atualizar a resposta "Como excluo minha conta e meus dados?" do `docs/faq.html` e `docs/exclusao-de-conta.html` para citar o caminho pelo app (menu → Excluir conta), só quando a versão com o botão estiver na loja.
- Trocar o texto do e-mail de convite por um link da loja (`supabase/functions/enviar-email-convite/index.ts`).
