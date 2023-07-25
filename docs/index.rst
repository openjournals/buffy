Buffy
=====
Buffy is an editorial bots generator, a service to provide a bot helping scientific journals manage submission reviews.

Buffy is a configurable Ruby application that –once deployed as a web service listening to incoming GitHub webhooks– provides a bot that interacts during the peer-review process with editors, reviewers and authors to help them perform actions on the review, the software being reviewed and its corresponding paper, automating common editorial tasks like those needed by the `Journal of Open Source Software <http://joss.theoj.org/>`_, `rOpenSci <https://ropensci.org/>`_, the `Journal of Open Source Education <http://jose.theoj.org/>`_ or `Scipy <https://github.com/scipy-conference/scipy_proceedings>`_.

Buffy is an Open Source project, `the code <https://github.com/openjournals/buffy>`_ is hosted at GitHub and released under a MIT license.


.. toctree::
   :caption: Getting started
   :maxdepth: 3

   installation
   configuration

.. toctree::
   :caption: Responders
   :maxdepth: 2

   available_responders
   labeling
   using_templates

.. toctree::
   :caption: Developer guides
   :maxdepth: 1

   custom_responder
