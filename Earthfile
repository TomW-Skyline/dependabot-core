VERSION 0.6
FROM ubuntu:20.04

shared:
    FROM scratch

    COPY .rubocop.yml .
    SAVE ARTIFACT .rubocop.yml

    COPY .gitignore .
    SAVE ARTIFACT .gitignore

deps:
    ARG DEBIAN_FRONTEND="noninteractive"

    RUN apt-get update \
     && apt-get upgrade -y \
     && apt-get install -y --no-install-recommends \
            build-essential \
            dirmngr \
            git \
            bzr \
            mercurial \
            gnupg2 \
            ca-certificates \
            curl \
            file \
            zlib1g-dev \
            liblzma-dev \
            tzdata \
            zip \
            unzip \
            openssh-client \
            software-properties-common \
            make \
     && rm -rf /var/lib/apt/lists/*

rubocop:
    FROM ruby:2.7.1

    ARG version=1.29.0

    RUN gem install rubocop -v ${version} --no-document

    WORKDIR /app
    VOLUME /app

    ENTRYPOINT [ "rubocop" ]

    SAVE IMAGE rubocop

lint:
    LOCALLY

    ARG autocorrect
    ARG --required path

    WITH DOCKER --load=+rubocop
        RUN docker run \
            --rm \
            -v $PWD:/app \
            rubocop \
            ${autocorrect:+"-A"} \
            $path
    END

all:
    BUILD \
        --platform=linux/amd64 \
        --platform=linux/arm64 \
        +docker

docker:
    FROM +deps

    LABEL org.opencontainers.image.title="dependabot-core"
    LABEL org.opencontainers.image.source="https://github.com/dependabot/dependabot-core"
    LABEL org.opencontainers.image.created="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
    LABEL org.opencontainers.image.revision="$(git rev-parse HEAD)"
    LABEL org.opencontainers.image.version="$(git describe --tags --abbrev=0)"

    ARG development
    ARG tag="latest"

    ENV DEPENDABOT_NATIVE_HELPERS_PATH="${DEPENDABOT_NATIVE_HELPERS_PATH:-/opt}"

    DO ./bundler+SETUP
    DO ./python+SETUP
    DO ./npm_and_yarn+SETUP

    # Elm is amd64 only, see:
    # - https://github.com/elm/compiler/issues/2007
    # - https://github.com/elm/compiler/issues/2232
    IF  [ "$TARGETARCH" == "amd64" ]
        DO ./elm+SETUP
    END

    DO ./composer+SETUP
    DO ./go_modules+SETUP
    DO ./hex+SETUP
    DO ./cargo+SETUP
    DO ./terraform+SETUP
    DO ./pub+SETUP

    DO ./common+CREATE_DEPENDABOT_USER

    COPY --chown=dependabot:dependabot LICENSE /home/dependabot

    USER dependabot

    ENV HOME="/home/dependabot"
    WORKDIR ${HOME}

    CMD [ "/bin/sh" ]

    IF [ $development ]
        USER root

        RUN --mount=type=cache,target=/var/cache/apt \
            apt-get update \
         && apt-get install -y \
                vim \
                strace \
                ltrace \
                gdb \
                shellcheck \
         && rm -rf /var/lib/apt/lists/*

        USER dependabot

        WORKDIR /home/dependabot/dependabot-core

        COPY --chown=dependabot:dependabot --dir \
            omnibus \
            git_submodules \
            terraform \
            github_actions \
            hex \
            elm \
            docker \
            nuget \
            maven \
            gradle \
            cargo \
            composer \
            go_modules \
            python \
            pub \
            npm_and_yarn \
            bundler \
            common \
            .

        USER root

        DO ./common/+CONFIGURE_GIT_USER

        # Install Ruby dependencies
        RUN cd common \
         && bundle install

        RUN GREEN='\033[0;32m'; NC='\033[0m'; \
            for d in `find $PWD -type f -mindepth 2 -maxdepth 2 \
                # -not -path "$PWD/common/Gemfile" \
                -name 'Gemfile' | xargs dirname`; do \
                echo && \
                echo "---------------------------------------------------------------------------" && \
                echo "Installing gems for ${GREEN}$(realpath --relative-to=$PWD $d)${NC}..." && \
                echo "---------------------------------------------------------------------------" && \
                cd $d && bundle install; \
            done
        RUN cd omnibus \
         && bundle install

        # Make omnibus gems available to bundler in root directory
        RUN echo 'eval_gemfile File.join(File.dirname(__FILE__), "omnibus/Gemfile")' > Gemfile

        USER dependabot

        COPY --chown=dependabot:dependabot --dir bin .

        # Create directory for volume containing VSCode extensions,
        # to avoid reinstalling on image rebuilds
        RUN mkdir -p ~/.vscode-server ~/.vscode-server-insiders

        # Declare pass-thru environment variables used for debugging
        ENV LOCAL_GITHUB_ACCESS_TOKEN=""
        ENV LOCAL_CONFIG_VARIABLES=""

        SAVE IMAGE --push "dependabot/dependabot-core-development:$tag"
    ELSE
        SAVE IMAGE --push "dependabot/dependabot-core:$tag"
    END
