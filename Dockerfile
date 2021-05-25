FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update
RUN apt install -y ruby-full build-essential zlib1g-dev git vim tmux

RUN echo '# Install Ruby Gems to ~/gems' >> ~/.bashrc
RUN echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
RUN echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc

RUN gem install jekyll bundler

RUN git clone https://github.com/mav8557/mav8557.github.io 

CMD ["/bin/bash"]
