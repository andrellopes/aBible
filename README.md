# aBible (Android-only)

App Flutter (Bíblia) – versão open-source focada em Android.

Este repositório contém o código fonte do app, com instruções para configurar seu ambiente local e publicar sua própria versão.

## Índice

- [Como rodar localmente (Android)](#como-rodar-localmente-android)
- [Configuração de Segredos e IDs (Android)](#configuração-de-segredos-e-ids-android)
- [Publicação (Google Play)](#publicação-google-play)
- [Fonte dos Dados da Bíblia](#fonte-dos-dados-da-bíblia)
- [Dependências Principais](#dependências-principais)
- [Troubleshooting](#troubleshooting)
- [Contribuições](#contribuições)

## Como rodar localmente (Android)

### Pré-requisitos

- **Flutter SDK**: Versão 3.8 ou superior. [Instalação](https://flutter.dev/docs/get-started/install).
- **Android Studio**: Com Android SDK e ferramentas de build. [Download](https://developer.android.com/studio).
- **JDK**: Versão 11 ou superior para Android builds.
- Dispositivo Android ou emulador configurado.

### Passos

1. Clone o repositório e navegue até a pasta:

   ```bash
   git clone <url-do-repo>
   cd aBible
   ```

2. Instale as dependências do Flutter:

   ```bash
   flutter pub get
   ```

3. Verifique se tudo está configurado:

   ```bash
   flutter doctor
   ```

4. Execute o app em modo debug:

   ```bash
   flutter run
   ```

Nota: Este projeto é focado em Android; builds para iOS não são suportados.

## Configuração de Segredos e IDs (Android)

Nada sensível é versionado. Você deve configurar localmente:

### 1) Assinatura de APK/AAB (Android)

1. Gere sua keystore de release (ou use uma existente):
   - Exemplo (opcional): `keytool -genkey -v -keystore release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias seu-alias`
2. Copie `android/key.properties.example` para `android/key.properties` e preencha:

```properties
storeFile=../release-key.jks
storePassword=SUA_SENHA
keyAlias=SEU_ALIAS
keyPassword=SUA_SENHA
```

Observações:

- O build de release usa `key.properties` automaticamente SE o arquivo existir.
- Caso não exista, o build de release usará a assinatura de debug (apenas para testes locais).
- `release-key.jks` e `key.properties` estão no .gitignore e não serão versionados.

### 2) AdMob (Android)

- Android: o App ID do AdMob é injetado via placeholder de manifesto `ADMOB_APP_ID`.
  - Opcional: defina em `android/gradle.properties` (não comite segredos):
    - `ADMOB_APP_ID=ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy`
  - Se não definir, um App ID de TESTE do Google será usado por padrão.
- Unidades de anúncio (ad units): edite `lib/constants/ad_ids.dart` e substitua os IDs de TESTE pelos seus IDs reais.

Referência de IDs de TESTE do Google (Android):

- App ID: `ca-app-pub-3940256099942544~3347511713`
- Banner: `ca-app-pub-3940256099942544/6300978111`

### 3) Compras no app (IAP)

- O ID do produto está em `lib/services/purchase_service.dart` (`_kProVersionId`). Ajuste conforme seus produtos no Google Play.
- Nenhuma chave secreta de servidor é necessária neste projeto (uso do plugin `in_app_purchase`).

### 4) Firebase/Google Services (opcional)

- Se vier a usar, NÃO versione `android/app/google-services.json`.
- Adicione-o localmente e mantenha-o fora do Git.

## Publicação (Google Play)

1. Configure keystore e `key.properties`.
2. Coloque seus App IDs/AdUnits do AdMob.
3. Ajuste o ID do produto de IAP, se necessário.
4. Gere o artefato de release:

- Android: `flutter build appbundle` ou `flutter build apk --release`

Nota: iOS não é suportado neste repositório (Android-only).

## Fonte dos Dados da Bíblia

Os bancos de dados SQLite da Bíblia foram obtidos do repositório [damarals/biblias](https://github.com/damarals/biblias), licenciado sob MIT. Este projeto referencia e utiliza esses dados conforme a licença.

## Dependências Principais

Este projeto utiliza as seguintes dependências principais (ver `pubspec.yaml` para detalhes):

- `google_mobile_ads`: Integração com anúncios AdMob.
- `in_app_purchase`: Suporte a compras no app (focado em Android).
- `sqflite`: Banco de dados SQLite local para armazenamento.
- `provider`: Gerenciamento de estado da aplicação.
- Outros plugins incluem `path_provider`, `shared_preferences`, etc., para funcionalidades como navegação e configurações.

## Troubleshooting

Aqui vão algumas dicas para problemas comuns:

- **Erro ao executar `flutter run`**: Certifique-se de que um dispositivo Android está conectado ou um emulador está rodando. Verifique com `flutter devices`.
- **Build falha**: Execute `flutter clean` e `flutter pub get`. Verifique se JDK 11+ está instalado e configurado.
- **Anúncios AdMob não aparecem**: Em desenvolvimento, use os IDs de teste. Para produção, substitua por IDs reais no `lib/constants/ad_ids.dart`.
- **Compras no app não funcionam**: Configure os produtos no Google Play Console e certifique-se de que o ID em `lib/services/purchase_service.dart` corresponde.
- **Problemas com keystore**: Se houver erros de assinatura, gere uma nova keystore ou verifique as senhas em `android/key.properties`.

Para mais ajuda, consulte a [documentação do Flutter](https://flutter.dev/docs) ou abra uma issue no repositório.

## Contribuições

Contribuições são bem-vindas! Siga estes passos:

1. Fork o repositório.
2. Crie uma branch para sua feature (`git checkout -b feature/nova-feature`).
3. Faça commits claros e teste suas mudanças.
4. Abra um Pull Request descrevendo as alterações.

Por favor, mantenha o foco em Android e evite adicionar dependências iOS.
