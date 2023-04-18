<div align="center">
  <h1 align="center">🪗 Kass - Starknet NFT bridge</h1>
</div>

This repo contains the reference implementation of the Kass protocol.

---

Kass is a bridge between Ethereum and Starknet allowing the transfer of ERC721 and ERC1155 tokens. Kass is compatible with both L1 and L2 native tokens.

## 🎡 Architecure overview

Kass protocol is composed of 2 smart contracts on Ethereum and Starknet, offering approximately the same interface.

```mermaid
%%{
  init: {
    'theme': 'base',
    'themeVariables': {
      'mainBkg': '#0D1114',
      'primaryTextColor': '#f7f7f7',
      'primaryBorderColor': '#7C03AE',
      'secondaryColor': '#7C03AE',
      'tertiaryColor': '#fff',
      'noteTextColor': '#f7f7f7',
      'noteBkgColor': '#191B1D',
      'noteBorderColor': '#909193'
    }
  }
}%%
classDiagram
  class L1Kass["L1 Kass"] {
    createL1Wrapper()
    requestL2Wrapper()

    claimL1Ownership()
    requestL2Ownership()

    deposit()
    requestDepositCancel()
    cancelDeposit()

    withdraw()
  }

  class L2Kass["L2 Kass"] {
    createL2Wrapper()
    requestL1Wrapper()

    claimL2Ownership()
    requestL1Ownership()

    deposit()

    withdraw()
  }
```

### Wrapper Creation

In order to successfuly bridge assets through chains, Kass needs to deploy an equivalent token contract (either ERC721 or ERC1155) on the target chain. This process is called the wrapper creation.

#### L2 Wrapper creation

```mermaid
%%{
  init: {
    'theme': 'base',
    'themeVariables': {
      'mainBkg': '#0D1114',
      'primaryTextColor': '#f7f7f7',
      'primaryBorderColor': '#7C03AE',
      'secondaryColor': '#7C03AE',
      'tertiaryColor': '#fff',
      'noteTextColor': '#f7f7f7',
      'noteBkgColor': '#191B1D',
      'noteBorderColor': '#909193',
      'sequenceNumberColor': '#0D1114'
    }
  }
}%%
sequenceDiagram
  box rgb(25, 27, 29) Ethereum / L1
    participant L1 User
    participant L1 Kass
    participant Starknet Core
  end

  box rgb(25, 27, 29) Starknet / L2
    participant L2 Kass
  end

  autonumber
  L1 User ->> L1 Kass: requestL2Wrapper()
  L1 Kass ->> Starknet Core: send message
  Starknet Core ->> L2 Kass: createL2Wrapper()
  Note over L2 Kass: Deploy wrapper
```

> *Creation of a wrapper on Starknet, in order to deposit L1 native tokens to Starknet.*

### L1 Wrapper creation

```mermaid
%%{
  init: {
    'theme': 'base',
    'themeVariables': {
      'mainBkg': '#0D1114',
      'primaryTextColor': '#f7f7f7',
      'primaryBorderColor': '#7C03AE',
      'secondaryColor': '#7C03AE',
      'tertiaryColor': '#fff',
      'noteTextColor': '#f7f7f7',
      'noteBkgColor': '#191B1D',
      'noteBorderColor': '#909193',
      'sequenceNumberColor': '#0D1114'
    }
  }
}%%
sequenceDiagram
  box rgb(25, 27, 29) Ethereum / L1
    participant L1 User
    participant L1 Kass
    participant Starknet Core
  end

  box rgb(25, 27, 29) Starknet / L2
    participant L2 Kass
    participant L2 User
  end

  autonumber
  L2 User ->> L2 Kass: requestL1Wrapper()
  L2 Kass ->> Starknet Core: send message
  L1 User ->> L1 Kass: createL1Wrapper()
  L1 Kass ->> Starknet Core: consume message
  Note over L1 Kass: Deploy wrapper
```

> *Creation of a wrapper on Ethereum, in order to deposit L2 native tokens to Starknet.*

## ⚠️ Disclaimer

This repo contains highly experimental code. Use at your own risk.
